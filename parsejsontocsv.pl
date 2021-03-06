#!/usr/bin/perl

#
# The MIT License (MIT)
#
# Copyright (c) 2015 yaalaa
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# Manages translations, source and exported
#

use strict;
use Getopt::Long;
use Scalar::Util qw(blessed reftype);
use Data::Dumper;
use Text::CSV_XS;
use JSON;

$|=1;

local $/;

# hello message
printf "Hi there, I'm %s\n", $0;

my $usage = <<EOT;
Converts Parse JSON table data to CSV

Usage:
  <me> [option ..]
  
  Options:
    --help                  - this help screen
    --in-json <path>        - specifies input JSON file
    --out-csv <path>        - specifies output CSV file
    --user-table            - to parse user table

EOT

if ( scalar( @ARGV ) <= 0 ) # no arguments
{
    printf $usage;
    exit( 0 );
}

my $optResult = GetOptions( 
    "help"          => \my $printHelp,
    "in-json=s"     => \my $optInJson,
    "out-csv=s"     => \my $optOutCsv,
    "user-table"    => \my $tableUser,
    );

if ( !$optResult || $printHelp )
{
    printf $usage;
    exit( 0 );
}
    
if ( !$optInJson )
{
    printf "Error: no input file specified\n";
    exit( 0 );
}

if ( !$optOutCsv )
{
    printf "Error: no output file specified\n";
    exit( 0 );
}
    
my $in;

if ( !open( $in, "<:utf8", $optInJson ) ) # failed
{
    printf "Error: open failed[%s]: %s\n", $optInJson, $!;
    exit( 0 );
}

my $json_text   = <$in>;
my $perl_scalar = decode_json( $json_text );

close( $in );

# printf "Parsed: %s", Dumper( $perl_scalar );

my $out;

{{
    my $results = $perl_scalar->{"results"};
    
    if ( reftype $results ne "ARRAY" ) # no results array
    {
        printf "Error: no results array\n";
        last;
    }
    
    my $cnt = scalar( $results );
    
    if ( $cnt <= 0 ) # no item
    {
        printf "Error: no results\n";
        last;
    }
    
    # parse for columns
    my $firstOne = @$results[0];
    
    if ( reftype $firstOne ne "HASH" ) # first object is not a hash
    {
        printf "Error: first object is not a hash\n";
        last;
    }
    
    my $everyObjectPreColumnNames = [ "objectId" ];
    my $everyObjectPostColumnNames = [ "createdAt", "updatedAt" ];
    
    if ( $tableUser )
    {
        push(  @$everyObjectPreColumnNames, "username", "email" );
    }
    
    my $knownColumnNames = {};
    
    foreach my $cur ( @{ $everyObjectPreColumnNames } )
    {
        $knownColumnNames->{ $cur } = 1;
    }
    
    foreach my $cur ( @{ $everyObjectPostColumnNames } )
    {
        $knownColumnNames->{ $cur } = 1;
    }
    
    my $columnNames = [];

    foreach my $cur ( keys %$firstOne )
    {
        if ( !$knownColumnNames->{ $cur } )
        {
            push( @$columnNames, $cur );
        }
    }
    
    my @sortedColumnNames = sort { CORE::fc($a) cmp CORE::fc($b) } @$columnNames;
    
    my @outColumnNames;
    
    push( @outColumnNames, @$everyObjectPreColumnNames );
    push( @outColumnNames, @sortedColumnNames );
    push( @outColumnNames, @$everyObjectPostColumnNames );

    if ( !open( $out, ">:utf8", $optOutCsv ) ) # failed
    {
        printf "Error: open failed[%s]: %s\n", $optOutCsv, $!;
        last;
    }

    my $csv = Text::CSV_XS->new( { binary => 1, eol => "\n" } );
    
    if ( !$csv->print( $out, \@outColumnNames ) ) # failed
    {
        printf "Error: csv::print failed: %s\n", $csv->status();
        last;
    }
    
    foreach my $obj ( @{ $results } )
    {
        my $columns = [];
        
        foreach my $col ( @outColumnNames )
        {
            my $val = $obj->{ $col };
            
            push( @$columns, parseObjectToString( $val ) );
        }
        
        if ( !$csv->print( $out, $columns ) ) # failed
        {
            printf "Error: csv::print failed: %s\n", $csv->status();
            last;
        }
    }
}}

if ( $out )
{
    close( $out );
}


printf ".Done.\n";
    
exit( 0 );


sub parseObjectToString
{
    my $obj = shift @_;
    
    my $out = "";
    
    {{
        if ( reftype $obj ne "HASH" ) # not an object
        {
            last;
        }
        
        my $className = $obj->{"__type"};
        
        if ( $className eq "" )
        {
            last;
        }
        
        if ( $className eq "GeoPoint" )
        {
            $out = "{lat:".$obj->{"latitude"}.", lon:".$obj->{"longitude"}."}";
            last;
        }
        
        my $skipProps = { "__type" => 1 };
        
        if ( $className eq "Pointer" )
        {
            $className = $obj->{ "className" };
            $skipProps->{ "className" } = 1;
        }
        
        $out = $className."{";
        
        my $needComma = 0;
        
        foreach my $cur ( keys %$obj )
        {
            if ( !$skipProps->{ $cur } )
            {
                if ( $needComma )
                {
                    $out = $out.", ";
                }
                else 
                {
                    $needComma = 1;
                }
                
                $out = $out.$cur.":".parseObjectToString( $obj->{ $cur } );
            }
        }
        
        $out = $out."}";
    }}
    
    return $out ne "" ? $out : $obj;
}


    
    