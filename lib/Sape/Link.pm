package Sape::Link;
use strict;
use warnings;

use Carp;
use URI;

use Sape::Project;
use Sape::DB;

sub new {
    my ($class, $url_or_hashref) = @_;
    my $self = undef;
    if(ref($url_or_hashref) eq 'HASH'){
        my $hr = $url_or_hashref;
        croak('bad usage') if(
                              not defined $hr->{'site_url'}
                              or
                              not defined $hr->{'page_uri'}
                              );
        my $uri = URI->new($hr->{'site_url'} . $hr->{'page_uri'});
        $self = $hr;
        $self->{URI} = $uri;
        $self->{'project_id'} = 0 if not defined $self->{'project_id'};
    } else {
        my $url = $url_or_hashref;
        $url = 'http://'.$url if($url !~ /^http:/x);
        my $uri = URI->new($url);
        my $host = $uri->host();
        my $page = $uri->path();
        $page .= $uri->query() if $uri->query();
        $page .= $uri->fragment() if $uri->fragment();
        $self = {URI => $uri, 'site_url' => $host, 'page_uri' => $page};
        $self->{'project_id'} = 0;
    }
    bless $self, $class;
    return $self;
} # constructor - links with no project_id are not forbidden, but they are go
  # to the zeroth project

sub site_url{
    my $self = shift;
    return $self->{'site_url'};
}

sub page_uri {
    my $self = shift;
    return $self->{'page_uri'};
}

sub id {
    my $self = shift;
    return $self->{'link_id'};
}

sub project {
    my $self = shift;
    return Sape::Project->new($self->{'project_id'});
}

1;
__END__

=head1 SYNOPSIS
    my $project = Sape::Project->create(); # new empty project
    my $link1 = Sape::Link->create({
        'site_url' => $host,
        'page_uri' => $page,
    }); # new link
    $project->add($link1);
    $project->remove($link1);
    $link->project
    $link->project($project)
    my $link2 = Sape::Link->create({});
=cut
