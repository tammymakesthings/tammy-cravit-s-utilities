#!/usr/bin/perl -w
############################################################################
# resolve_coverage.pl: Parse the output of a Ruby simplecov_erb text file,
#                      and generate a report with code context for missed
#                      lines.
#
# Version 1.00, 2018-06-15, tammycravit@me.com
############################################################################

use File::Spec;
use File::Basename;
use File::Slurp;
use Term::ANSIColor qw(:constants);
use Cwd;
use Getopt::Long;

####################
# CONFIGURATION CONSTANTS
####################

$FILE_PREFIX              = "";
$FILE_SUFFIX              = "";
$EXAMPLE_PREFIX           = "";
$EXAMPLE_SUFFIX           = "\n";
$CONTEXT_SIZE             = 2;
$CONTEXT_UNCOVERED_MARKER = "->";
$CONTEXT_UNCOVERED_COLOR  = RED;
$FILENAME_COLOR           = BLUE;
$BARE_OUTPUT              = undef;

$cov_files = 0;
$cov_lines = 0;

####################
# Script begins here
####################

sub generate_file_context
{
  my ($filename, $lines_list) = @_;
  $filename =~ s@//@/@g;

  my @lines = @$lines_list;
  @content = read_file($filename, chomp => 1);

  if (length $FILE_PREFIX) { print $FILE_PREFIX; }

  if ($BARE_OUTPUT)
  {
    print "*** ", $filename, " ($#content lines)", "\n";
  }
  else
  {
    print
      BOLD, WHITE, "*** ", RESET
      BOLD, $FILENAME_COLOR, $filename, RESET,
      WHITE, " ($#content lines)", RESET,
      "\n";
  }
  print "\n";

  foreach my $which_line (@lines)
  {
    $which_line--;
    if (length $EXAMPLE_PREFIX) { print $EXAMPLE_PREFIX; }

    for ($i = $which_line - $CONTEXT_SIZE; $i <= $which_line + $CONTEXT_SIZE; $i++)
    {
      if ($i <= $#content)
      {
        my $color = ($i == $which_line ? $CONTEXT_UNCOVERED_COLOR : WHITE);
        my $number_color = CYAN;
        my $reset = RESET;
        if ($BARE_OUTPUT)
        {
          printf "%s%s%s%5.0d:%s %s%s\n",
            "",
            ($i == $which_line ? $CONTEXT_UNCOVERED_MARKER : (" " x length($CONTEXT_UNCOVERED_MARKER))),
            "",
            $i+1,
            "",
            $content[$i],
            "";
        }
        else
        {
          printf "%s%s%s%5.0d:%s %s%s\n",
            $color,
            ($i == $which_line ? $CONTEXT_UNCOVERED_MARKER : (" " x length($CONTEXT_UNCOVERED_MARKER))),
            $number_color,
            $i+1,
            $color,
            $content[$i],
            $reset;
        }
      }
    }

    if (length $EXAMPLE_SUFFIX) { print $EXAMPLE_SUFFIX; }
    $cov_lines++;
  }

  if (length $FILE_SUFFIX) { print $FILE_SUFFIX; }
  $cov_files++;
}

GetOptions(
  "file-prefix=s" => \$FILE_PREFIX,
  "file-suffix=s" => \$FILE_SUFFIX,
  "example-prefix=s" => \$EXAMPLE_PREFIX,
  "example-suffix=s" => \$EXAMPLE_SUFFIX,
  "context-size=i"   => \$CONTEXT_SIZE,
  "context-marker=s" => \$CONTEXT_UNCOVERED_MARKER,
  "bare"             => \$BARE_OUTPUT,
);

$coverage_file = File::Spec->rel2abs($ARGV[0]);
$project_root  = dirname($coverage_file);
do
{
  $project_root  = dirname($project_root);
}
until ((-d "$project_root/coverage") || ($project_root eq '/'));
die "Could not find project root starting from $coverage_file\n" if ($project_root eq "/");

unless ($BARE_OUTPUT)
{
  print "****************************************************************************\n";
  print "* resolve_coverage.pl: Parse a simplecov-erb coverage report and generate  *\n";
  print "*                      contextual code snippets for uncovered lines.       *\n";
  print "*                                                                          *\n";
  print "* Version 1.00, 2018-06-15, Tammy Cravit, tammycravit\@me.com               *\n";
  print "****************************************************************************\n";
  print "\n";

  print BOLD, MAGENTA, "==> Coverage file: ", RESET, MAGENTA, $coverage_file, "\n", RESET;
  print BOLD, MAGENTA, "==> Project root : ", RESET, MAGENTA, $project_root, "\n", RESET;
  print BOLD, MAGENTA, "==> Context lines: ", RESET, MAGENTA, $CONTEXT_SIZE, "\n", RESET;
  print "\n";
}


die "Usage: $0 coverage_file.txt\n" unless (-f $coverage_file);

open (COVERAGE, $coverage_file) || die;
while (<COVERAGE>)
{
  chomp;
  if ($_ =~ m/^(\S+)\b.*?missed:\s?([0123456789,]+)/)
  {
    $filename = $1;
    @lines = split(/,/, $2);
    generate_file_context("$project_root/$filename", \@lines);
  }
}
close (COVERAGE);

if ($BARE_OUTPUT)
{
  print "resolve_coverage.pl processed ", $cov_lines, " examples from ", $cov_files,
        " files.\n";
}
else
{
  print "Done. Processed ",
        CYAN, $cov_lines, RESET,
        " examples from ",
        CYAN, $cov_files, RESET,
        " files.\n";
}
exit 0;
