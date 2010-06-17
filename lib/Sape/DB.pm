package Sape::DB;
use strict;
use warnings;

#use base 'DBIx::Class::Schema';
use DBI;

#use Data::Dumper;


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


1;