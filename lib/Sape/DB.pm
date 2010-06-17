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
  
  # бросаем исключение, если такого пользователя нет в базе
  die "no such user $login" unless $self->user_id;
  
  return $self;
} # конструктор


sub disconnect {
  my $self = shift;
  $self->{dbh}->disconnect;
} # деструктор


sub user_id {
  my $self = shift;
  my ($login, $password) = @_;
  $login = $self->{login} unless $login;
  $password = $self->{password} unless $password;

  return $self->{id} if $self->{id};
  
  # получаем id пользвателя (он такой же, как для RPC, но это можно изменить)
  my $user = $self->{dbh}->selectrow_hashref("
    SELECT id FROM users WHERE login = ? AND password = ?
  ", {}, $login, $password);

  # сохраняем его как часть объекта, чтобы лишний раз не лазить в базу
  $self->{id} = $user->{id} if $user;

  return $user->{id} if $user;
  return 0;
} # проверка, существует ли пользователь (если нет, то будет возвращен 0)


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
} # занесение в базу нового пользователя (иначе сохранение его ссылок работать не будет)


sub clear { 
  my $self = shift;
  my $user_id = shift;

  $user_id = $self->user_id unless $user_id;

  # записываем номера проектов пользователя, чтобы по ним удалить ссылки
  my $pr_ids = $self->{dbh}->selectcol_arrayref("
    SELECT id FROM projects WHERE user_id = ?
  ", {}, $user_id);

  # удаляем проекты пользователя
  $self->{dbh}->do("
    DELETE FROM projects WHERE user_id = ?
  ", {}, $user_id);

  # удаляем ссылки по номерам проектов
  foreach my $pr_id (@$pr_ids){
    $self->{dbh}->do("
      DELETE FROM links WHERE project_id = ?
    ", {}, $pr_id);
  }
} # удаление из базы всех записей по пользователю


sub save {
  my $self = shift;
  my ($projects) = @_;

  # получаем id пользвателя (он такой же, как для RPC, но это можно изменить)
  my $user_id = $self->user_id;

  # если такой логин не зарегистрирован ...
  unless($user_id){
#    die "no such login '$login'";
     return;
  }

  # записываем новые проекты из памяти
  my $sql_pr_insert = $self->{dbh}->prepare("
    INSERT INTO projects (id, user_id, name) VALUES (?, ?, ?)
  ");
  # ... и ссылки по новым проектам
  my $sql_link_insert = $self->{dbh}->prepare("
    INSERT INTO links (id, project_id, site_url, page_uri, is_indexed, action)
    VALUES (?, ?, ?, ?, ?, ?)
  ");
  
  # цикл записи в БД
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
} # сохранение данных пользователя в БД


sub load {
  my $self = shift;

  my $user_id = $self->user_id;  

  # если не обнаружили такого пользователя в базе ...
  unless($user_id){
    return {};
#    die "no such user $login";
  }

  # все проекты
  my $projects = $self->{dbh}->selectall_arrayref("
    SELECT * FROM projects WHERE user_id = ?
  ", {Slice => {}}, $user_id);

  # выгружаем ссылки по каждому проекту
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
} # извлечение данных из базы в память


1;