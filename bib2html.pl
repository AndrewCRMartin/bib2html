#!/usr/bin/perl -s
#*************************************************************************
#
#   Program:    bib2html
#   File:       bib2html.pl
#   
#   Version:    V1.0
#   Date:       18.01.18
#   Function:   Convert a BibTeX file to HTML
#   
#   Copyright:  (c) Dr. Andrew C. R. Martin, UCL, 2018
#   Author:     Dr. Andrew C. R. Martin
#   Address:    Institute of Structural and Molecular Biology
#               Division of Biosciences
#               University College
#               Gower Street
#               London
#               WC1E 6BT
#   EMail:      andrew@bioinf.org.uk
#               
#*************************************************************************
#
#   This program is not in the public domain, but it may be copied
#   according to the conditions laid out in the accompanying file
#   COPYING.DOC
#
#   The code may be modified as required, but any modifications must be
#   documented so that the person responsible can be identified. If 
#   someone else breaks this code, I don't want to be blamed for code 
#   that does not work! 
#
#   The code may not be sold commercially or included as part of a 
#   commercial product except as described in the file COPYING.DOC.
#
#*************************************************************************
#
#   Description:
#   ============
#   Convert a .bib file (in a restricted format) to a .html file
#
#*************************************************************************
#
#   Usage:
#   ======
#
#*************************************************************************
#
#   Revision History:
#   =================
#   V1.0   18.01.18   Original   By: ACRM
#
#*************************************************************************
# Add the path of the executable to the library path
#use FindBin;
#use lib $FindBin::Bin;
# Or if we have a bin directory and a lib directory
#use Cwd qw(abs_path);
#use FindBin;
#use lib abs_path("$FindBin::Bin/../lib");

use strict;

#*************************************************************************
# Global variables
#
$::PMIDURL = "http://www.ncbi.nlm.nih.gov/pubmed/%s";
$::DOIURL  = "http://dx.doi.org/%s";
$::EndSentence = 0;
$::tocCSS = <<__EOF;
<style type='text/css'>
.bibtoc {
  font: 12pt bold Helvetica,Arial,sans-serif;
  width: 70%;
    margin-left: auto;
    margin-right: auto;
  text-align: center;
}
.bibtoc a {
    text-decoration: none;
}
.bibtoc a:link, a:visited, a:hover, a:active {
  color: black;
}
.bibtocsection {
  padding: 0.25em 0em;
}
.bibtochead { font-weight: bold;
display: block;
}
.bibtochead::after {
/*  content: ":"; */
}

</style>
__EOF
#*************************************************************************

UsageDie() if(defined($::h));

main();

#*************************************************************************
sub main
{
    # Read all data into an array of hashes
    my @entries = ();
    my $hEntry  = {};
    my $tocFp;

    $::c = $::toc if(defined($::toc)); # Allow -toc or -c for table of contents 

    if(defined($::c))
    {
        if(open($tocFp, '>', $::c))
        {
            if(defined($::css))
            {
                print $tocFp $::tocCSS;
            }
                   
            print $tocFp "<div class='bibtoc'>\n";
        }
        else
        {
            print STDERR "Can't write table of contents: $::c\n";
            exit 1;
        }
    }

    while(%{$hEntry} = ReadEntry())
    {
        DeTeXifyEntry($hEntry);
        FixCase($hEntry, 'title');
        FixCase($hEntry, 'booktitle');
        push @entries, $hEntry;
        $hEntry = {};
    }

    # Sort on year if required
    if(defined($::y))
    {
        @entries = SortEntriesOnYear(defined($::r), @entries);
    }

    # Define types and title for each type
    my @types  = ('article',  'review',  'chapter',       
                  'meeting abstract',  '!',     'submitted');
    my @labels = ('Articles', 'Reviews', 'Book chapters', 
                  'Meeting Abstracts', 'Other', 'Submitted');

    # Remove any types/labels that haven't been used
    my($aTypes, $aLabels) = FilterTypesAndLabels(\@entries, \@types, \@labels);
    @types  = @$aTypes;
    @labels = @$aLabels;

    # Display by type
    if(defined($::t))
    {
        my $count = 0;
        foreach my $type (@types)
        {
            my $id=$type;
            $id = 'other' if($type eq '!');
            $id = ''      if($type eq '*');
            $id =~ s/\s//g;

            print "\n\n\n<h2><a id='$id'>$labels[$count]</a></h2>\n";
            if($tocFp)
            {
                print $tocFp "<div class='bibtocsection'>\n";
                print $tocFp "<span class='bibtochead'><a href='#$id'>$labels[$count]</a></span>\n";
            }
            DisplayEntries($type, $tocFp, \@types, @entries);
            print $tocFp "</div> <!-- bibtocsection -->\n" if($tocFp);
            $count++;
        }
    }
    else
    {
        DisplayEntries('*', $tocFp, \@types, @entries);
    }

    if($tocFp)
    {
        print $tocFp "</div> <!-- bibtoc -->\n";
        close $tocFp;
    }

}

#*************************************************************************
sub FilterTypesAndLabels
{
    my($aEntries, $aTypes, $aLabels) = @_;
    my @types  = ();
    my @labels = ();
    my $count  = 0;

    foreach my $type (@$aTypes)
    {
        if($count == 0)
        {
            push @types, $type;
            push @labels, $$aLabels[$count];
        }
        else
        {
            foreach my $entry (@$aEntries)
            {
                if(defined($entry->{type}) && ($entry->{type} eq $type))
                {
                    push @types, $type;
                    push @labels, $$aLabels[$count];
                    last;
                }
            }
        }
        $count++;
    }
    return(\@types, \@labels);
}


#*************************************************************************
sub DisplayEntries
{
    my($showType, $tocFp, $aTypes, @entries) = @_;

    my $nEntries = scalar(@entries);
    my $lastYear = '';
    my $shownTocEntry = 0;

    for(my $i=0; $i<$nEntries; $i++)
    {
        # Determine whether we are going to display this entry
        my $doit = 0;
        $doit = 1 if($showType eq '*');
        $doit = 1 if(($showType eq 'article') && 
                     (!defined($entries[$i]->{type}) || 
                      ($entries[$i]->{type} eq 'article')));
        $doit = 1 if(defined($entries[$i]->{type}) && 
                     ($showType eq $entries[$i]->{type}));
        if($showType eq '!')
        {
            if(defined($entries[$i]->{type}))
            {
                $doit = 1;
                foreach my $otherType (@$aTypes)
                {
                    if($entries[$i]->{type} eq $otherType)
                    {
                        $doit = 0;
                        last;
                    }
                }
            }
        }

        # Display it if required
        if($doit)
        {
            my $year = $entries[$i]->{year};
            $year = "\u$year";
            if($year ne $lastYear)
            {
                my $id=$showType;
                $id  =  'other' if($showType eq '!');
                $id  =  ''      if($showType eq '*');
                $id .=  $year;
                $id  =~ s/\s//g;

                print "\n<h3><a id='$id'>$year</a></h3>\n";
                if($tocFp)
                {
                    print $tocFp " .. " if($shownTocEntry);
                    print $tocFp "<a href='#$id'>$year</a>\n";
                    $shownTocEntry = 1;
                }
                $lastYear = $year;
            }
            DisplayEntry(%{$entries[$i]});
        }
    }
}

#*************************************************************************
sub SortEntriesOnYear
{
    my ($reverse, @entries) = @_;

    my @sorted = ();
    if($reverse)
    {
        @sorted = sort{ $a->{year} <=> $b->{year} } @entries;
    }
    else
    {
        @sorted = sort{ $b->{year} <=> $a->{year} } @entries;
    }
        
    return(@sorted);
}

#*************************************************************************
sub DisplayEntry
{
    my(%entry) = @_;

    if($entry{'class'} eq "article")
    {
        DisplayArticle(%entry);
    }
    elsif($entry{'class'} eq "incollection")
    {
        DisplayInCollection(%entry);
    }
    elsif($entry{'class'} eq "misc")
    {
        DisplayMisc(%entry);
    }
    else
    {
        print STDERR "!!! No handler for entry type: $entry{'class'}\n";
    }
}

#*************************************************************************
sub DisplayArticle
{
    my(%entry) = @_;

    if(CheckEntry(\%entry, 'author', 'year', 'title', 'journal', 'volume', 'pages'))
    {
        print "<p>\n";
        PrintAuthor(%entry);
        PrintYear(%entry);
        PrintTitleWithLink(\%entry, 'title', 'url', 'pmid', '');
        PrintType(%entry);
        EndSentence();
        PrintJournal(%entry);
        PrintVolumePages(%entry);
        EndSentence();
        PrintNote(%entry);
        PrintWeb(%entry);
        PrintSuppMat(%entry);
        PrintDOI(%entry);
        PrintPMID(%entry);
        PrintPDF(%entry);
        EndSentence();
        print "</p>\n";
    }
}


#*************************************************************************
sub DisplayInCollection
{
    my(%entry) = @_;

    if(CheckEntry(\%entry, 'author', 'year', 'title', 'booktitle', 'editor', 'publisher'))
    {
        print "<p>\n";
        PrintAuthor(%entry);
        PrintYear(%entry);
        EndSentence();
        PrintTitleWithLink(\%entry, 'title', 'url', 'pmid', '');
        PrintType(%entry);
        EndSentence();
        PrintTitleWithLink(\%entry, 'booktitle', 'bookurl', '', 'In ');
        PrintEdition(%entry);
        PrintEditor(%entry);
        PrintVolumePages(%entry);
        PrintPublisher(%entry);
        EndSentence();
        PrintNote(%entry);
        PrintWeb(%entry);
        PrintSuppMat(%entry);
        PrintDOI(%entry);
        PrintPMID(%entry);
        PrintPDF(%entry);
        EndSentence();
        print "</p>\n";
    }
}

#*************************************************************************
sub DisplayMisc
{
    my(%entry) = @_;

    if(CheckEntry(\%entry, 'author', 'year'))
    {
        print "<p>\n";
        PrintAuthor(%entry);
        PrintYear(%entry);
        PrintTitleWithLink(\%entry, 'title', 'url', 'pmid', '');
        PrintType(%entry);
        EndSentence();
        PrintJournal(%entry);
        EndSentence() if(defined($entry{'note'}));
        PrintNote(%entry);
        PrintVolumePages(%entry);
        EndSentence();
        PrintPCT(%entry);
        EndSentence();
        PrintWeb(%entry);
        PrintSuppMat(%entry);
        PrintDOI(%entry);
        PrintPMID(%entry);
        PrintPDF(%entry);
        EndSentence();
        print "</p>\n";
    }
}


#*************************************************************************
sub EndSentence
{
    if($::EndSentence)
    {
        print ".\n";
    }
    $::EndSentence = 0;
}

#*************************************************************************
sub PrintPCT
{
    my(%entry) = @_;
    if(defined($entry{'pct'}) && defined($entry{'pcturl'}))
    {
        print " <a href='$entry{'pcturl'}'>$entry{'pct'}</a>";
        $::EndSentence = 1;
    }
    elsif(defined($entry{'pct'}))
    {
        print " $entry{'pct'}";
        $::EndSentence = 1;
    }
    elsif(defined($entry{'pcturl'}))
    {
        print " [<a href='$entry{'pcturl'}'>PCT</a>]";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintPublisher
{
    my(%entry) = @_;
    if(defined($entry{'publisher'}))
    {
        print " ($entry{'publisher'}";
        if(defined($entry{'address'}))
        {
            print ", $entry{'address'}";
        }
        print ")";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintEdition
{
    my(%entry) = @_;
    if(defined($entry{'edition'}))
    {
        print " ($entry{'edition'} edition)";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintEditor
{
    my(%entry) = @_;
    if(defined($entry{'editor'}))
    {
        my $editor = $entry{'editor'};
        my $EdString = "Ed.";
        if($editor =~ /\sand\s/)
        {
            $EdString = "Eds.";
        }
        $editor = FixNameList($editor);
        print " $EdString $editor";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintVolumePages
{
    my(%entry) = @_;
    if(defined($entry{'volume'}) && defined($entry{'pages'}))
    {
        print " <b>$entry{'volume'}:</b>$entry{'pages'}";
        $::EndSentence = 1;
    }
    elsif(defined($entry{'volume'}))
    {
        print " Volume: $entry{'volume'}";
        $::EndSentence = 1;
    }
    elsif(defined($entry{'pages'}))
    {
        print " Pages: $entry{'pages'}";
        $::EndSentence = 1;
    }

}

#*************************************************************************
sub PrintJournal
{
    my(%entry) = @_;
    if(defined($entry{'journal'}))
    {
        if(($entry{'type'} eq 'submitted') || ($entry{'year'} eq 'submitted'))
        {
            print " Submitted to";
        }
        print" <i>$entry{'journal'}</i>";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintYear
{
    my(%entry) = @_;
    if(defined($entry{'year'}))
    {
        if(($entry{'type'} ne 'submitted') && ($entry{'year'} ne 'submitted'))
        {
            print " ($entry{'year'})";
        }
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub FixNameList
{
    my ($names) = @_;
    my $andCount = () = $names =~ /\sand\s/g;
    for(my $i=0; $i<$andCount-1; $i++)
    {
        $names =~ s/ and /, /;
    }
    return($names);
}

#*************************************************************************
sub PrintAuthor
{
    my(%entry) = @_;

    if(defined($entry{'author'}))
    {
        my $author = $entry{'author'};
        $author = FixNameList($author);
        print "$author";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintNote
{
    my(%entry) = @_;
    if(defined($entry{'note'}))
    {
        print " $entry{'note'}";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintType
{
    my(%entry) = @_;
    if(defined($entry{'type'}))
    {
        if($entry{'type'} ne 'submitted')
        {
            my $type = $entry{'type'};
            $type = 'Book chapter' if($type eq 'chapter');
            $type = "\u$type";
            print " <b>($type)</b>";
            $::EndSentence = 1;
        }
    }
}

#*************************************************************************
sub PrintWeb
{
    my(%entry) = @_;
    if(defined($entry{'web'}))
    {
        print " [<a href='$entry{'web'}'>Web server</a>]";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintSuppMat
{
    my(%entry) = @_;
    if(defined($entry{'suppmat'}))
    {
        print " [<a href='$entry{'suppmat'}'>Supplementary Material</a>]";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintPMID
{
    my(%entry) = @_;
    if(defined($entry{'pmid'}))
    {
        my $url=$entry{'pmid'};
        $url=sprintf($::PMIDURL, $url);

        print " [<a href='$url'>PMID: $entry{'pmid'}</a>]";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintDOI
{
    my(%entry) = @_;
    if(defined($entry{'doi'}))
    {
        my $url=$entry{'doi'};
        $url=sprintf($::DOIURL, $url);

        print " [<a href='$url'>doi:$entry{'doi'}</a>]";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintPDF
{
    my(%entry) = @_;
    if(defined($entry{'pdf'}))
    {
        my $label = 'PDF';
        $label = 'Free PDF' if($entry{'pdf'} =~ /free/);
        print " [<a href='$entry{'pdf'}'>$label</a>]";
        $::EndSentence = 1;
    }
    if(defined($entry{'pubpdf'}))
    {
        print " [<a href='$entry{'pubpdf'}'>PDF from publisher</a>]";
        $::EndSentence = 1;
    }
    if(defined($entry{'subpdf'}))
    {
        print " [<a href='$entry{'subpdf'}'>PDF as submitted</a>]";
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub PrintTitleWithLink
{
    my($hEntry, $titleItem, $urlItem1, $urlItem2, $preText) = @_;

    if(defined($$hEntry{$titleItem}))
    {
        my $title = $$hEntry{$titleItem};
        $title =~ s/\.*\s*$//;  # Remove trailing space and '.'
        print " $preText" if($preText ne '');

        if(($urlItem1 ne '') && defined($$hEntry{$urlItem1}))
        {
            print " <a href='$$hEntry{$urlItem1}'>$title</a>";
            $::EndSentence = 1;
        }
        elsif(($urlItem2 ne '') && defined($$hEntry{$urlItem2}))
        {
            my $url = $$hEntry{$urlItem2};
            if($urlItem2 eq 'pmid')
            {
                $url=sprintf($::PMIDURL, $url);
            }
            
            print " <a href='$url'>$title</a>";
        }
        else
        {
            print " <b>$title</b>";
        }
        $::EndSentence = 1;
    }
}

#*************************************************************************
sub CheckEntry
{
    my($hEntry, @fields) = @_;
    foreach my $field (@fields)
    {
        if(!defined($$hEntry{$field}))
        {
            print STDERR "Required field, '$field', missing from entry '$$hEntry{'key'}'\n";
#            return(0);
        }
    }
    return(1);
}

#*************************************************************************
# Changes to all lower case (except for the first character, except for things in {}
# which are stripped
sub FixCase
{
    my($hEntry, $item) = @_;
    my @data = split(//,$$hEntry{$item});
    my $newdata = '';
    my $special = 0;

    for(my $pos=0; $pos<scalar(@data); $pos++)
    {
        my $char = $data[$pos];
        if($char eq '{')
        {
            $special = 1;
        }
        elsif($char eq '}')
        {
            $special = 0;
        }
        else
        {
            if($special)
            {
                $newdata .= "$char";
            }
            elsif($pos == 0)
            {
                $newdata .= "\U$char";
            }
            else
            {
                $newdata .= "\L$char";
            }
        }
    }

    $$hEntry{$item} = $newdata;
}

#*************************************************************************
sub DeTeXifyEntry
{
    my($hEntry) = @_;

    foreach my $key (keys %$hEntry)
    {
        my $data = $$hEntry{$key};
        # Replace \emph{} with <i></i>
        while($data =~ /(.*?)\\emph\{(.*?)\}(.*)/)
        {
            $data = "$1<i>$2</i>$3";
        }
        # Replace ~ with &nbsp;
        $data =~ s/\~/\&nbsp;/g;
        # Replace ` with '
        $data =~ s/\`/\'/g;
        # Replace --- with - 
        $data =~ s/---/-/g;
        # Replace -- with - 
        $data =~ s/--/-/g;

        $$hEntry{$key} = $data;
    }

}


#*************************************************************************
sub ReadEntry
{
    my $inEntry = 0;
    my %entry = ();
    my $type;
    while(<>)
    {
        chomp;
        if(/^@/)
        {
            $inEntry = 1;
            my $line = substr($_,1);
            $line = "\L$line";
            ($entry{'class'}, $entry{'key'}) = split(/\{/, $line);
        }
        elsif(/^\}/)
        {
            last;
        }
        elsif($inEntry)
        {
            my $data;
            s/^\a+//;
            if(/=/)
            {
                ($type, $data) = split(/\s*=\s*/,$_,2);
                $type =~ s/\s//g;
                $type = "\L$type";
                $entry{$type} = $data;
            }
            elsif($type ne '')
            {
                s/^\s+//;
                $entry{$type} .= " $_";

                if(($type eq 'type') || ($type eq 'year'))
                {
                    $entry{$type} = "\L$entry{$type}";
                }
            }
        }
    }

    foreach my $key (keys %entry)
    {
        $entry{$key} =~ s/^\s+//;
        $entry{$key} =~ s/\s+$//;
        $entry{$key} =~ s/,$//;
        $entry{$key} =~ s/^\"//;
        $entry{$key} =~ s/\"$//;
    }

    return(%entry);

}

#*************************************************************************
sub UsageDie
{
    print <<__EOF;

bib2html V1.0 (c) 2018, UCL, Dr. Andrew C.R. Martin

Usage: bib2html [-y [-r]][-t][-c=toc.html [-css]] file.bib > file.html
       -y      Sort by year
       -r      Reverse the sort
       -t      Group by publication type
       -c|-toc Create table of contents
       -css    Write CSS into the toc.html file

This is a very simple program to generate an HTML file from a .bib file.
It does not have style files - if you want to change the style, you need
to edit the Perl. However the Perl is designed to allow this quite 
easily and uses a similar organization to the BibTeX style language.

Currently it is restricted in the formatting of .bib files it will accept.

The HTML does not include any headers, etc. as it is designed to be 
embedded in a larger page.

__EOF
    exit 0;
}
