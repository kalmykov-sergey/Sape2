package Sape::Index::Alexa;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

our @EXPORT = qw(
    alexa_stats    
);

our $VERSION = '0.01';


use LWP::UserAgent;
use URI;
use XML::Simple;
use Carp;
#use Data::Dumper;

my $ua = LWP::UserAgent->new;

sub alexa_stats {
    my $site = shift;
    $site = 'http://'.$site if $site !~ m#^http://#; 
    my $uri = URI->new('http://data.alexa.com/data');
    $uri->query_form(
		     cli => 10,  # формат вывода (10 - xml)
		     dat => 's', # данные : s - статистика, n - внешние ссылки
		     url => $site,
		     );
    my $resp = $ua->get($uri);
    croak($resp->status_line) unless $resp->is_success;
    my $ref = XMLin($resp->content);
    my %stat = (rank => 0, sites => 0);
    #print Dumper($ref);
    if(ref($ref->{SD}) eq 'HASH'){ # no such host or ...
	eval{$stat{rank} = $ref->{SD}->{POPULARITY}->{TEXT} || 0};
	eval{$stat{sites} = $ref->{SD}->{LINKSIN}->{NUM} || 0};
	eval{$stat{created} = $ref->{SD}->{CREATED}->{DATE}};
	return %stat if (wantarray);
	return $stat{rank};
    } elsif(ref($ref->{SD}) eq 'ARRAY'){
	foreach(@{$ref->{SD}}){
	    $stat{rank} = $_->{POPULARITY}->{TEXT} if $_->{POPULARITY};
	    $stat{sites} = $_->{LINKSIN}->{NUM} if $_->{LINKSIN};
	}
    }
    return %stat if (wantarray);
    return $stat{rank};
}

1;

__END__
=pod
=cut
