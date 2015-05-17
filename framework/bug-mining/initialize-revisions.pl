#!/usr/bin/env perl

use warnings;
use strict;
use File::Basename;
use List::Util qw(all);
use Cwd qw(abs_path);
use Getopt::Std;

use lib (dirname(abs_path(__FILE__)) . "/../core/");
use Constants;
use Project;
use DB;
use Utils;

############################## ARGUMENT PARSING
#
# Issue usage message and quit
#
sub _usage {
    die "usage: " . basename($0) . " -p project_id [-v version_id] [-w working_dir]";
}

my %cmd_opts;
getopts('p:v:w:', \%cmd_opts) or _usage();

my ($PID, $VID, $working) =
    ($cmd_opts{p},
     $cmd_opts{v} // undef,
     $cmd_opts{w} // "$SCRIPT_DIR/projects"
    );

_usage() unless all {defined} ($PID, $working); # $VID can be undefined

# Check format of target version id
if (defined $VID) {
    $VID =~ /^(\d+)(:(\d+))?$/ or die "Wrong version id format ((\\d+)(:(\\d+))?): $VID!";
}

############################### VARIABLE SETUP
# Temporary directory
my $TMP_DIR = Utils::get_tmp_dir();
system("mkdir -p $TMP_DIR");
# Set up project
my $project = Project::create_project($PID, $working);
$project->{prog_root} = $TMP_DIR;

############################### MAIN LOOP
# figure out which IDs to run script for
my @ids = $project->get_version_ids();
if (defined $VID) {
    if ($VID =~ /(\d+):(\d+)/) {
        @ids = grep { ($1 <= $_) && ($_ <= $2) } @ids;
    } else {
        # single vid
        @ids = grep { ($VID == $_) } @ids;
    }
}

foreach my $vid (@ids) {
    printf ("%4d: $project->{prog_name}\n", $vid);

    my $v1 = $project->lookup("${vid}b");
    my $v2 = $project->lookup("${vid}f");

    $project->checkout_id("${vid}b");
    $project->sanity_check();
    $project->initialize_revision($v1);
    my ($src_b, $test_b) = ($project->src_dir($v1), $project->test_dir($v1));

    $project->checkout_id("${vid}f");
    $project->sanity_check();
    $project->initialize_revision($v2);
    my ($src_f, $test_f) = ($project->src_dir($v2), $project->test_dir($v2));

    die "Source directories don't match for buggy and fixed revisions of $vid" unless $src_b eq $src_f;
    die "Test directories don't match for buggy and fixed revisions of $vid" unless $test_b eq $test_f;
}
system("rm -rf $TMP_DIR");
