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
sub create {
    return new()
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