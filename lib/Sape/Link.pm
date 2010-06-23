package Sape::Link;
use strict;
use warnings;

use Carp;
use URI;

sub new {
    my ($class, $url_or_hashref) = @_;
    my $self = undef;
    if(ref($url_or_hashref) eq 'HASH'){
        my $hr = $url_or_hashref;
        croak('bad usage') if(
                              not $hr->{'site_url'}
                              or
                              not $hr->{'page_uri'}
                              );
        my $uri = URI->new($hr->{'site_url'} . $hr->{'page_uri'});
        $self = $hr;
        $self->{URI} = $uri;
    } else {
        my $url = $url_or_hashref;
        $url = 'http://'.$url if($url !~ /^http:/x);
        my $uri = URI->new($url);
        my $page = substr($uri->as_string, length($uri->host));
        $self = {URI => $uri, 'site_url' => $uri->host, 'page_uri' => $page};        
    }
    bless $self, $class;
    return $self;
}

sub site_url{
    my $self = shift;
    return $self->{'site_url'};
}

sub page_uri {
    my $self = shift;
    return $self->{'page_uri'};
}

1;
__END__
