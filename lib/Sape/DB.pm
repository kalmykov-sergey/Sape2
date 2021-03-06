package Sape::DB;
use strict;
use warnings;

#use 'DBIx::Class::Schema';
use DBI;
use Carp;

use Sape::Link;
use Sape::Project;

#use Data::Dumper;

sub _new {
  my ($class, $dbi_connection_string) = @_;
  $dbi_connection_string ||= 'dbi:SQLite:sape.db';
  my $dbh = DBI->connect($dbi_connection_string) or croak($!);
  my $self = {db => $dbh};
  bless $self, $class;
#  $self->{db}->do("set names 'cp1251'");  
  return $self;
} # constructor - database connector


sub _recreate_links_table {
  my ($self) = @_;
  my $create_link_sql = <<'END_OF_LINKS_SQL';
CREATE TABLE link (
  link_id INTEGER PRIMARY KEY,
  project_id INTEGER,
  site_url TEXT NOT NULL,
  page_uri TEXT NOT NULL
);
END_OF_LINKS_SQL

  $self->{db}->do("DROP table link") or croak($self->{db}->errstr);
  $self->{db}->do($create_link_sql) or croak($self->{db}->errstr);
  return 1;
} # truncate links table (drop if some bad previous creation) 


sub _insert_link {
  my ($self, $link) = @_;
  croak "$link is not a Link" if(! $link->isa('Sape::Link'));
  my $link_exists = $self->{db}->selectrow_hashref
    (
     "select * from link where site_url like ? and page_uri like ?",
     {},
     $link->site_url,
     $link->page_uri
     );
  return $link_exists->{link_id} if $link_exists;
  $self->{db}->do
    (
     "insert into link (site_url, page_uri) values (?, ?)",
     {},
     $link->site_url,
     $link->page_uri
     ) or croak($self->{db}->errstr);
  return $self->{db}->last_insert_id('', '', '', '');
} # insert link into db, returns last_insert_id


sub _delete_link {
  my ($self, $link) = @_;
  croak "$link is not a Link" if(! $link->isa('Sape::Link'));
  my $delete_sql = 'delete from link where site_url like ? and page_uri like ?';
  if($link->{'link_id'}){
    $delete_sql = 'delete from link where link_id = ' . $link->{'link_id'} .
      ' and site_url like ? and page_uri like ?';
  }
  my $rows = $self->{db}->do
    (
     $delete_sql,
     {},
     $link->site_url,
     $link->page_uri
     );
  return int($rows);
} # delete link, using link_id or not, returns number of deleted (1 or 0) links


sub _read_link {
  
}


sub _read_project {
  my ($self, $project_id_or_name) = @_;
  my $links_arr_ref = [];
  return Sape::Project->new({
                             'project_id' => $project_id,
                             links => $links_arr_ref,
                             });
}

1;
__END__















sub connect {
  my $class = shift;
  my ($login, $password) = @_;
  my $dbh = DBI->connect("dbi:mysql:sape", 'lavan', 'Gh2mooK6C');
  my $self = {dbh => $dbh, login => $login, password => $password};
  bless $self, $class;
  
  # ������� ����������, ���� ������ ������������ ��� � ����
  die "no such user $login" unless $self->user_id;
  
  return $self;
} # �����������


sub disconnect {
  my $self = shift;
  $self->{dbh}->disconnect;
} # ����������


sub user_id {
  my $self = shift;
  my ($login, $password) = @_;
  $login = $self->{login} unless $login;
  $password = $self->{password} unless $password;

  return $self->{id} if $self->{id};
  
  # �������� id ����������� (�� ����� ��, ��� ��� RPC, �� ��� ����� ��������)
  my $user = $self->{dbh}->selectrow_hashref("
    SELECT id FROM users WHERE login = ? AND password = ?
  ", {}, $login, $password);

  # ��������� ��� ��� ����� �������, ����� ������ ��� �� ������ � ����
  $self->{id} = $user->{id} if $user;

  return $user->{id} if $user;
  return 0;
} # ��������, ���������� �� ������������ (���� ���, �� ����� ��������� 0)


sub create_user {
  my $self = shift;
  my ($login, $password, $id) = @_;

  unless($id){
    $self->{dbh}->do("
      INSERT INTO users (login, password) VALUES (?, ?)
    ", {}, $login, $password);
    $id = $self->{dbh}->{mysql_insertid};
    return $id;
  } else {
    $self->{dbh}->do("
      INSERT INTO users (id, login, password) VALUES (?, ?, ?)
    ", {}, $id, $login, $password);
  }
} # ��������� � ���� ������ ������������ (����� ���������� ��� ������ �������� �� �����)


sub clear { 
  my $self = shift;
  my $user_id = shift;

  $user_id = $self->user_id unless $user_id;

  # ���������� ������ �������� ������������, ����� �� ��� ������� ������
  my $pr_ids = $self->{dbh}->selectcol_arrayref("
    SELECT id FROM projects WHERE user_id = ?
  ", {}, $user_id);

  # ������� ������� ������������
  $self->{dbh}->do("
    DELETE FROM projects WHERE user_id = ?
  ", {}, $user_id);

  # ������� ������ �� ������� ��������
  foreach my $pr_id (@$pr_ids){
    $self->{dbh}->do("
      DELETE FROM links WHERE project_id = ?
    ", {}, $pr_id);
  }
} # �������� �� ���� ���� ������� �� ������������


sub save {
  my $self = shift;
  my ($projects) = @_;

  # �������� id ����������� (�� ����� ��, ��� ��� RPC, �� ��� ����� ��������)
  my $user_id = $self->user_id;

  # ���� ����� ����� �� ��������������� ...
  unless($user_id){
#    die "no such login '$login'";
     return;
  }

  # ���������� ����� ������� �� ������
  my $sql_pr_insert = $self->{dbh}->prepare("
    INSERT INTO projects (id, user_id, name) VALUES (?, ?, ?)
  ");
  # ... � ������ �� ����� ��������
  my $sql_link_insert = $self->{dbh}->prepare("
    INSERT INTO links (id, project_id, site_url, page_uri, is_indexed, action)
    VALUES (?, ?, ?, ?, ?, ?)
  ");
  
  # ���� ������ � ��
  foreach my $pr (@$projects){
    $sql_pr_insert->execute($pr->{id}, $user_id, $pr->{name});
    foreach my $link (@{$pr->{links}}){
      $sql_link_insert->execute(
        $link->{id}, 
        $pr->{id}, 
        $link->{'site_url'}, 
        $link->{'page_uri'}, 
        $link->{'is_indexed'},
        $link->{'action'},
      );
    }
  }
} # ���������� ������ ������������ � ��


sub load {
  my $self = shift;

  my $user_id = $self->user_id;  

  # ���� �� ���������� ������ ������������ � ���� ...
  unless($user_id){
    return {};
#    die "no such user $login";
  }

  # ��� �������
  my $projects = $self->{dbh}->selectall_arrayref("
    SELECT * FROM projects WHERE user_id = ?
  ", {Slice => {}}, $user_id);

  # ��������� ������ �� ������� �������
  my $sql_links_select = $self->{dbh}->prepare("
    SELECT * FROM links WHERE project_id = ?
  ");
  foreach my $pr (@{$projects}){
    $sql_links_select->execute($pr->{id});
    my $links = $sql_links_select->fetchall_arrayref({});
    my @sorted_links = sort{$a->{'site_url'} cmp $b->{'site_url'}} @$links;
    $pr->{links} = \@sorted_links;
  }
  my @sorted = sort{$a->{name} cmp $b->{name}} @$projects;
  return \@sorted;
} # ���������� ������ �� ���� � ������


sub get_result {
    my $file_id = shift;

    my @nonindexed_links = ();
    my %bad_donors = ();
    
    my $dbh = DBI->connect('dbi:mysql:seo:localhost', 'seo', 'seo2009');
    my $file_info = $dbh->selectrow_hashref("
        select engine, name from backlinks_files where id = '$file_id'
    ");
    my ($engine, $file_name) = ($file_info->{engine}, $file_info->{name});
    my $q_select = $dbh->prepare("
        select id, url from backlinks_links where file_id = '$file_id'
    ");
    $q_select->execute;
    while(my $row = $q_select->fetchrow_hashref){
        my $info = $dbh->selectrow_hashref("
            select checked, bad_donor
            from backlinks_check where link_id = ?
        ", undef, $row->{id});
        push @nonindexed_links, $row->{url} unless $info->{checked};
        $bad_donors{$row->{url}} = $info->{bad_donor} 
            if bad($info->{bad_donor}); 
    }
    $q_select->finish;
    $dbh->disconnect;

    return {
        links => \@nonindexed_links, 
        donors => \%bad_donors,
        name => $file_name,
        engine => $engine,
    };
}

sub file_to_db {
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

sub check_last_file {
    my $dbh = DBI->connect('dbi:mysql:seo:localhost','seo','seo2009');
    my $file_id = $dbh->selectrow_hashref("
        select id from backlinks_files order by id desc limit 1
    ")->{id};
    $dbh->disconnect;
    check_file($file_id);
}

sub check_file($) {
    my $file_id = shift;
    my $dbh = DBI->connect('dbi:mysql:seo;host=mail.plarson.ru','seo','seo2009') or die "connection err:$!";
    
    my ($engine, $user, $name) = $dbh->selectrow_array("
        select engine, user, name from backlinks_files where id = ?
    ", undef, $file_id);

=pod
    if ($user ne 'anonymous'){
        my $count = $dbh->selectrow_hashref("
            select count(id) as num from backlinks_links where file_id = '$file_id'
        ")->{num};
        BackLinks::Mail::notify($user, "�������� $name", 
            "���������� �� ��������� �������� ���������� ����� $name". 
            "�� ������ �� ������:
                http://mail.plarson.ru:81/cgi-bin/monitor.cgi?file=$file_id"
        ) if($count > 30);
    }
=cut

    my $q_fetch = $dbh->prepare("
        select id, url from backlinks_links where file_id = '$file_id'
    ");
    my $q_check_inserted = $dbh->prepare("
        select count(id) as ok from backlinks_check where link_id = ?
    ");
    my $q_insert = $dbh->prepare("
        insert into backlinks_check (link_id, engine, checked, ip, bad_donor)
        values (?, ?, ?, INET_ATON(?), ?)
    ");
    $q_fetch->execute;
    while(my $row = $q_fetch->fetchrow_hashref){
        $q_check_inserted->execute($row->{id});
        next if($q_check_inserted->fetchrow_hashref->{ok});
        my $checked = LinkIndex::check($row->{url}, $engine);
        print $row->{url},' is  ',$checked," by $engine\n";
        my $bad_donor = is_bad_donor($row->{url});
        print "is $bad_donor\n";
        $q_insert->execute(
            $row->{id}, $engine, $checked, $LinkIndex::ip, $bad_donor);
    }
    $q_fetch->finish;
    $q_insert->finish;
    $q_check_inserted->finish;
    $dbh->disconnect;

    if ($user ne 'anonymous' and $user ne 'chpi_rf@mail.ru') {
        my $result = get_result($file_id);
        my $file_name = $result->{name};
        my @nonindexed_links = @{$result->{links}};
        my %bad_donors = %{$result->{donors}};
        $file_name = $file_name.'.csv';
        my $str = BackLinks::File::result_to_csv_format(\@nonindexed_links, \%bad_donors);

        BackLinks::Mail::send_results(
            $user, 
            "�������� $name", 
            "���������� �������� $name",
            $file_name,
            $str,
        );
    }
}

sub delete_file($) {
    my $file_id = shift;
    my $dbh = DBI->connect('dbi:mysql:seo;host=mail.plarson.ru','seo','seo2009');
    $dbh->do("
        update backlinks_files set invisible=1 where id='$file_id'
    ");
    $dbh->disconnect;
}

sub clear_db {
    my $dbh = DBI->connect('dbi:mysql:seo;host=mail.plarson.ru','seo','seo2009');
    my $files_ref = $dbh->selectcol_arrayref("
      select id from backlinks_files where invisible=1
    ");
    foreach my $file (@$files_ref){
      my $links_ref = $dbh->selectcol_arrayref("
        select id from backlinks_links where file_id = '$file'
      ");
      foreach my $linkid (@$links_ref){
        $dbh->do("
          delete from backlinks_check where link_id = '$linkid'
        ");
      }
      $dbh->do("delete from backlinks_links where file_id = '$file'");
      $dbh->do("delete from backlinks_files where id = '$file'");
    }
    $dbh->disconnect;
    
}

sub recheck_file($) {
    my $file_id = shift;
    my $dbh = DBI->connect('dbi:mysql:seo;host=mail.plarson.ru','seo','seo2009') or croak("connection err:$!");
    $dbh->do("
        delete from backlinks_check where link_id in 
            (select id from backlinks_links where file_id='$file_id')
    ");
    $dbh->disconnect;
    check_file($file_id);
}

sub daemon_check {
    my $file_id = shift;
    my $pid = fork();
    #If i am children?
    if($pid eq '0'){
        #Close owners handles
        close(STDIN);
        close(STDOUT);
        close(STDERR);
        #I am not terminal programm. Closing session or die.
        my $works = "${$}_works.txt";
        my $stderr = "${$}_err.txt";
        my $stdout = "${$}_out.txt";
        croak("cannot redirect STD streams: $!") if (
                                                    not open STDERR, '>', $stderr
                                                    or 
                                                    not open STDOUT, '>', $stdout
                                                    );
        open my $w, '>', $works or croak("$!");
        close $w;
	eval{
          LinkIndex::reconnect();
          recheck_file($file_id);
        } or carp $@;
        unlink $works;
    }else{
        #All ok.
        if($pid){
            print STDERR "Daemon started.\n";
        }else{
            print STDERR "Error: cannot fork.\n";
        }
        exit;
    };
}


1;