package Sape::Project;
use strict;
use warnings;

use DBI;


sub new {
    my $class = shift;
    my $links_arr_ref = shift;
    my $self = {links => $links_arr_ref};
    bless $self, $class;
}

sub 