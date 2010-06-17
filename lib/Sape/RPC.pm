package Sape::RPC;
use strict;
use warnings;

use Carp;

use HTTP::Cookies;
use Encode;
use Digest::MD5 qw(md5_hex);
require RPC::XML;
require RPC::XML::Client;

use Data::Dumper;

# cookie_jar файл не используется, поскольку все куки имеют атрибут discard,
# поэтому LWP их все равно не сохраняет 
# => для каждой серии запросов нужно переподключаться


sub call {
  my $self = shift;
  my $request = RPC::XML::request->new(@_);
  my $resp = $self->{client}->send_request($request);
  if (ref $resp){
    if($resp->is_fault){
      # TODO: надо решить, как лучше: 
      # бросать исключение или обрабатывать код тут же
      croak $resp->string, Dumper $request;
      return $resp->code;
    }
    return $resp;
  } else {
    die $resp;
  }
} # вызов RPC-функции


sub login {
  my ($class, $login, $password) = @_;

  my $client = RPC::XML::Client->new(
    'http://api.sape.ru:80/xmlrpc/?v=extended'
    #'http://api.sape.ru:80/xmlrpc/'
  );
  $client->useragent->cookie_jar(HTTP::Cookies->new);
  my $self = {client => $client};
  bless $self, $class;


  my $response = $self->call(
      'sape.login',
      RPC::XML::string->new($login),
      RPC::XML::string->new(md5_hex($password)),
      RPC::XML::boolean->new('true'),
  );
  $self->{user} = {};
  $self->{user}{id} = int($response->value);
  $self->{user}{login} = $login;
  $self->{user}{password} = $password;
  return $self;
} # конструктор - соединение с Sape.ru


sub get_projects {
  my $self = shift;
  $self->{projects} = {};
  my $resp = $self->call('sape.get_projects');
  my $projects = [];
  foreach(@$resp){
    push @$projects, {
      name => $_->{name}->value, 
      id => $_->{id}->value
    };
  }
  $self->{projects} = $projects;
  return $projects;
} # получение списка проектов


sub get_project_links {
  my ($self, $project, $filter) = @_;

  # если ищем по названию или id, то надо переопределить $project
  unless (ref $project) {
    ($project, my @dummy) = 
      grep{$_->{name} eq $project or $_->{id} == int($project)} 
      @{$self->{projects}};
  }

  my @prs = @{$self->{projects}};
  my ($project_num, @dummy1) = 
    grep{$prs[$_]->{id} == $project->{id}} 
    (0..$#prs);

  my $project_id = $project->{id};
  my $resp = $self->call('sape.get_project_links', RPC::XML::int->new($project_id));
  my $links = [];
  foreach(@$resp){
#    die Dumper($_);
    next unless (not defined $filter or $_->{status}->value eq $filter);
    push @$links, {
      id => $_->{id}->value,
      'site_url' => $_->{site_url}->value,
      'page_uri' => $_->{page_uri}->value,

    };
  }
  $self->{projects}[$project_num]{links} = $links;
  return $links;
} # получение ссылок одного проекта
  # filter may be 'WAIT_SEO', 'OK', 'ERROR', 'SLEEP' or 'WAIT_WM'


sub get_all_links {
  my $self = shift;
  my $projects = $self->get_projects;
  my $links = [];
  foreach(@$projects){
    push @$links, @{$self->get_project_links($_)};
  }
  return $links;
} # проекты и все ссылки по ним


sub get_all {
  my $self = shift;
  $self->get_all_links;
} # вся информация

sub refresh {
  my $self = shift;
  $self->get_all;
} # обновить всю информацию


sub send_actions {
  my $self = shift;
  my $actions = shift;
  my @to_delete = @{$actions->{'delete'}};
  $self->placements_delete(@to_delete) if scalar @to_delete;
} # модифицировать базу Sape.ru


=pod
sub get_links_id {
    my $project = shift;
    get_projects() unless(%$projects);
    unless ($project =~ /^\d+$/) {
      $project = $projects->{$project}
    }
    my $resp = call('sape.get_project_links', RPC::XML::int->new($project));
    my %links = map{$_->{site_url}->value.$_->{page_uri}->value => $_->{id}->value} @$resp;
    return \%links;
}
=cut

sub accept_links {
  my ($self, @ids) = @_;
  return $self->call('sape.placements_accept_seo', RPC::XML::array->new(@ids))->value;
} # перевод списка ссылок в группу 'OK' по id



sub placements_delete {
  my ($self, @ids) = @_;
  return $self->call('sape.placements_delete', RPC::XML::array->new(@ids))->value;
} # удаление списка ссылок по id


sub get_placement_status {
  my ($self, $link_id) = @_;
  return $self->call('sape.get_placement_status', RPC::XML::int->new($link_id));
} # показывает статус ссылки


1;