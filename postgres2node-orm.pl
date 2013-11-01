#!/usr/bin/perl

use strict;
use warnings;

#main

my ($filename, $outdir) = @ARGV;
die("$0 databaseDefinition.sql outputdir\n") unless defined $filename || undef $outdir;
die("outputdir must be a directory\n") unless -d $outdir;

open my $input, '<', $filename or die("can't open $filename: $!\n");

my $fullfile = "";
while(<$input>) {
    $fullfile .= $_;
}

print "Parsing $filename, extracting tables\n";

my @modules = ();

while ( $fullfile =~ /CREATE TABLE ([a-z0-9_]+) \((.+?)\)\;/misg )
{
    push(@modules, $1);
    our ($module, $enter, $key);
	$enter = 0;
    $key = "";
    $module =
<<HERE;
module.exports = (db, cb) => {
    db.define("$1",
    /* definition */
    {
HERE
    foreach( split(/\n/, $2, -1) ) {
    if( (defined $_ ) and !($_ =~ /^$/)) {
            my ($name, $type, $options) = get_options($_);
            if($name =~ /primary|constraint/i) {
                if($_ =~ /primary key\s*\((.+?)\)/i ) {
                    $key = "";
                    foreach(split (',' , $1)) {
                        my $value = $_;
                        $value =~ s/'|"//g;
                        $key .= "'$value',"
                    }
                    $key = substr $key, 0, -1;
                    
                }
                next;
            }
            $module .= "        $name : " . &get_fields($type, $options) .",\n";
            $enter = 1;
        }
    }
    #remove ,\n
    if($enter) {
        $module = substr $module, 0, -2;
    }
    $module .=
<<HERE;
    
    },
    /* options */
    {
HERE
    if($key ne "") {
        $module .= "        id: [$key]";
    }
    $module .=
<<HERE;

    });
    
    return cb();
};
HERE

    open my $output, '>', "$outdir/$1.ts" or die("Unable to create $outdir/$1.ts");
    print $output $module;
    close($output);
}
close($input);

print "Creating $outdir/index.ts";

create_index(\@modules, $outdir);

print "\nDone\n";

exit(0);

sub get_fields {

    my $type 	= do { @_ ? shift : 'error' };
    my $options = do { @_ ? shift : 'error'};
    
    ($type eq 'error' || $options eq 'error') && die("wrong parameters");

    our($_type, $type_size, $rational, $time, $defaultValue ) = 
    (
        #_type
             $type =~ /(big|small)?int|integer|(big|small)?serial|int[2|4|8]|serial[2|4|8]+/i ? "integer" : #number
             $type =~ /double precision|float[4|8]|real|decimal|numeric/i ? "float" : #number
             $type =~ /(var)?char|text|character( varying)?|varbit/i ? "text" : #text
             $type =~ /bool(ean)?/i ? "boolean" : #boolean
             $type =~ /time(stamp)|date?/i  ? "date" : #date
             $type =~ /json/i  ?  "object" : #object
             $type =~ /bit( varying)?|varbit|interval|box|bytea|cidr|circle|inet|line|lseg|macaddr|money|path|point|polygon|tsquery|tsvector|txid_snapshot|uuid|xml/i ? "binary" :
             "error",
         #type_size
             $type =~ /^(?:(?:var)?char|character(?: varying)?|int|serial)\s*\(?([0-9]+)\)?$/i ? $1 :
             $type =~ /big(int|serial)/i  ? '8' :
             $type =~ /serial|int(eger)?/i ? '4' :
             $type =~ /small(int|serial)/i ? '2' :
             '0',
         #rational
            '0',
         #time
            '0',
         #defautlValue
            ""
    );
       
       return '' if $_type eq "error";
    
    if($_type eq "float") {
        $rational = "true";
        $_type    = "number";
    }
     elsif($_type eq "integer") {
        $rational = "false";
        $_type    = "number";
     }
     elsif($_type eq "date") {
        $time = $type eq "date" ? "false" : "true";
     }
     
     if( $options =~ /default\s+?(.+?)$/i ) {
        my $s = $1;
        $s =~ s/'//g;
        $defaultValue = ", defaultValue: \"". ((substr $s, -1, 1) eq ',' ? (substr $s, 0 , -1)  : $s )   ."\"";
    }

    return
    "{ type: '$_type', required: " .
    (
        $options =~ /not null/i
            ? "true"
            : "false"
    )
    .
    (
        $type_size ne '0'
            ? ", size: $type_size"
            : ''
    )
    .
    (
        $rational  ne '0'
            ? ", rational: $rational"
            : ''
    )
    .
    (
        $time ne '0'
        ? ", time: $time "
        : ''
    )
    .
    $defaultValue
    .
    "}";
}

sub get_options {
    our( @ret ) = ("", "","");
    if ( $_[0] =~ /"?(?<name>[a-z0-9_]+)"?\s+?(?<type>[[a-z0-9\(\)_]+)\s*(?<options>.+?)?$/i ) {
        $ret[0] = "$+{name}";
        $ret[1] = "$+{type}";
        $ret[2] = "$+{options}" || "";
    }
    die("unable to extract name or type from: $_[0]: $ret[0] $ret[1]") if $ret[0] eq "" or $ret[1] eq "";
    return @ret;
}

sub create_index {
    my($modules, $outdir) = @_;
    
    open my $out, '>', "$outdir/index.ts" or die("unable to create $outdir/index.ts");
    
    my $module = "module.exports = (db, cb) => {\n";
    foreach(@$modules) {
        $module .= 
<<HERE;
    db.load('$_', (err) => {
        if(err) {
            return cb(err);
        }
        return cb();
    });

HERE
    }
    $module .= "};";
    
    print $out $module;
    close($out);
}