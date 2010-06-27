package Sape::Project;
use strict;
use warnings;

use DBI;

# CRUD operations

=pod
usage:
    my $pr = Sape::Project->create(fh => $filehandle, user => $user_obj);
or
    my $remote_user = Sape::RPC->login('login', 'password');
    my $projects = $remote_user->projects;
    my $pr = Sape::Project->create(rpc => $projects->[0]);
or just
    my $pr = Sape::Project->create(links => \@links [, user => 'anonymous']);
=cut
sub new {
    my ($class, $id_or_hash_ref) = @_;
    my $self = undef;
    if(ref($id_or_hash_ref) eq 'HASH'){
        my $hr = $id_or_hash_ref;
        return $class->new($hr->{'project_id'}) if defined $hr->{'project_id'};
        croak('bad usage: new({links => [...]})') if
            (not defined $hr->{links} or ref($hr->{links}) ne 'ARRAY');
        my $links_arr_ref = [];
        foreach my $link (@{$hr->{links}}){
            $link = Sape::Link->new($link) if (! $link->isa('Sape::Link'));
            push @$links_arr_ref, $link;
        }
        my $uri = URI->new($hr->{'site_url'} . $hr->{'page_uri'});
        $self = $hr;
        $self->{URI} = $uri;
        $self->{'project_id'} = 0 if not defined $self->{'project_id'};
    } else {
        my $id = $id_or_hashref;
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
}


sub id {
    
}

sub _create_from_file {
    my ($links_ref, $file_name, %opts) = @_;
    my $mime_type = $opts{mime_type} || 'text/plain';
    my $engine = $opts{engine} || 'qip';
    my $user = $opts{user} || 'anonymous';
    my $path = $opts{path};
    my @links = @$links_ref;
    s{^http://}{}i foreach @links;
    my $dbh = DBI->connect('dbi:mysql:seo:localhost', 'seo', 'seo2009');
    $dbh->do("set names 'cp1251'");
    $dbh->do('
        insert into backlinks_files (name, path, user, engine, mime_type) 
        values (?, ?, ?, ?, ?)
    ', undef, $file_name, $path, $user, $engine, $mime_type);
    my $file_id = $dbh->selectrow_hashref('
        select id from backlinks_files order by id desc limit 1
    ')->{id};
    foreach(@links){
    $dbh->do('
        insert into backlinks_links (url, file_id, site_id) values (?, ?, ?)
    ', undef, $_, $file_id, undef);
    }
    $dbh->disconnect;
    return $file_id;

}

sub read {
    
}


sub update {
    
}

sub delete {
    
}

1;

__END__