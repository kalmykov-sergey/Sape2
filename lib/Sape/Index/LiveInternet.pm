package Sape::Index::LiveInternet;

use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

our @EXPORT = qw(
    live_internet_stats    
);

our $VERSION = '0.01';

use LWP::UserAgent;
use Carp;

my $ua = LWP::UserAgent->new;

sub live_internet_stats {
    my $site = shift;
    my $url = "http://counter.yadro.ru/values?site=$site";
    my $resp = $ua->get($url);
    croak($resp->status_line) unless $resp->is_success;
    
    my $content = $resp->content;
    return if $content =~ /LI_error = 'Unregistered site:/;
    $content =~ s{LI_|;}{}g;
    $content =~ s{\015\012$}{}s;
    my %hash = map{split /\s*=\s*/} split(/\015\012/, $content);
    
    return \%hash;
}

1;

__END__
=pod
=cut