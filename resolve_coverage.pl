#!/usr/bin/perl -w
############################################################################
# resolve_coverage.pl: Parse the output of a Ruby simplecov_erb text file,
#                      and generate a report with code context for missed
#                      lines.
#
# Version 1.00, 2018-06-15, tammycravit@me.com
############################################################################
# Easy integration with Simplecov:
#
# 1. Copy this script into your Ruby project's bin/ directory.
#
# 2. Add the following to your Ruby project's Rakefile:
#
#   namespace :coverage do
#     desc "Generate a contextual report from the SimpleCov output"
#     task :resolve do
#       project_root = File.expand_path(File.join(File.dirname(__FILE__)))
#       system("#{project_root}/bin/resolve_coverage.pl #{project_root}/coverage/coverage.txt")
#     end
#   end
#
# 3. Add the following to the top of spec/spec_helper.rb:
#
#   require 'simplecov'
#   require 'simplecov-erb'
#
#   def run_coverage_resolver
#     project_root    = File.expand_path(File.join(File.dirname(__FILE__), ".."))
#     resolver_script = File.expand_path(File.join(project_root, "bin", "resolve_coverage.pl"))
#     coverage_txt    = File.expand_path(File.join(project_root, "coverage", "coverage.txt"))
#     detail_txt      = File.expand_path(File.join(project_root, "coverage", "coverage_detail.txt"))
#
#     system("#{resolver_script} --bare #{coverage_txt} > #{detail_txt}")
#     puts "Contextual coverage report generated for RSpec to #{detail_txt}."
#   end
#
#   SimpleCov.start do
#     add_group "Library", "lib"
#     add_group "Tests",   "spec"
#     # Add other groups etc. as needed.
#     SimpleCov.formatter = SimpleCov::Formatter::ERBFormatter
#   end
#
#   SimpleCov.at_exit do
#     SimpleCov.result.format!
#     run_coverage_resolver
#   end
#
# Now the plain text coverage detail report will be auto-generated into the
# file coverage/coverage_detail.txt after your specs run. If you want to
# generate a pretty-printed and colorized report on the fly, you can run
# something like:
#
#   $ rake coverage:resolve | less
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

# Prefix output to print before each new file is processed.
$FILE_PREFIX              = "";    # Override with --file-prefix

# Suffix output to print after each new file is processed.
$FILE_SUFFIX              = "";    # Override with --file-suffix

# Prefix output to print before each example is processed.
$EXAMPLE_PREFIX           = "";    # Override with --example-prefix

# Suffix output to print after each example is processed.
$EXAMPLE_SUFFIX           = "\n";  # Override with --example-suffix

# Number of lines of context on either side of each flagged line to output.
$CONTEXT_SIZE             = 2;     # Override with --context-size

# Marker to print at the start of each flagged line.
$CONTEXT_UNCOVERED_MARKER = "->";  # Override with --context-marker

# Suppress a lot of human-readable output (and color flags) for use when
# invoked via an Rake task.
$BARE_OUTPUT              = undef; # Override with --bare

# Color for the flagged line in non-bare output.
$CONTEXT_UNCOVERED_COLOR  = RED;

# Color for the filename line in non-bare output.
$FILENAME_COLOR           = BLUE;

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
  }

  if (length $FILE_SUFFIX) { print $FILE_SUFFIX; }
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
exit 0;

__END__
