package Sape;

use 5.010000;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Sape ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
    cron_check
    cron_sync	
);

our $VERSION = '0.01';


# Preloaded methods go here.
use Sape::RPC;
use Sape::DB;
use Sape::Index;
use Sape::HTML;

#use DBI;
use Data::Dumper;

my $debug = 0;

=pod
  Основные функции верхнего уровня (надо бы экспортировать их)
=cut


# список всех зарегистрированных паролей
# TODO: перенести в базу и извлекать отдельной процедурой
my %pwds = (
  kalmykov => 'kalmykov1A',
);

=pod
# чтобы использовать относительные пути в библиотеке, делаем так:
my $new_base_file = __FILE__;
my $dir = $1 if ($new_base_file =~ /(.*)(\/|\\)(\w+)\.(\w+)$/);
if($dir){
  chdir $dir or die "Cannot initialize Sape.pm";
}
=cut


sub cron_check {
  foreach(keys %pwds){
    my $user = Sape->new($_, $pwds{$_});
    $user->check_links();
    $user->save_to_db();
  }
} # проверка ссылок, запускается каждые n часов 
  # (n зависит от числа ссылок по всем логинам)


sub cron_sync {
  foreach(keys %pwds){
    my $local_user = Sape->new($_, $pwds{$_});
    my $actions_todo = $local_user->actions;

    my $remote_user;
    eval{
      $remote_user = Sape::RPC->login($_, $pwds{$_});
      $remote_user->send_actions($actions_todo);
    };
    die $@ if $@;

    print "refreshing ...\n" if $debug;
    $remote_user->refresh();
    $local_user->update_with($remote_user);
    $local_user->save_to_db();
  }
} # синхронизация с Sape.ru, запускается каждый час


sub register_new_user {
  my ($class, $login, $password) = @_;
  eval{
    my $user = Sape->new($login, $password);
  };
  unless($@){
    die "such user is already registered";
  }
  my $user = Sape->new('kalmykov', 'kalmykov1A');
  # TODO: пока чтобы сделать нового пользователя нужен старый (админский?)
  $user->{db}->create_user($login, $password);
}


sub new_html {
  my $class = shift;
  my $self = Sape::HTML->new();
  return $self;
}


=pod
    Объект Sape содержит в себе структуры {projects} и {db}
=cut


sub new {
  my $class = shift;
  my $self = {};
  my ($login, $password) = @_;
  bless $self, $class;
  $self->{user} = {login => $login, password => $password};
  eval{
    $self->{db} = Sape::DB->connect($login, $password);
  };
  die "Неверный логин или пароль: $@" if $@;
  
  $self->load_from_db; 

  return $self;
} # конструктор 


sub delete {
  my $self = shift;
  eval{ 
    $self->{db}->disconnect(); 
  };
  die "DataBase error: $@" if $@;
} # деструктор


sub load_from_db {
  my $self = shift;
  eval{
    $self->{projects} = $self->{db}->load;
  };

  die "DataBase error: $@" if $@;

  # добавляем в структуру проверочную ссылку
  foreach my $pr (@{$self->{projects}}){
    foreach my $link (@{$pr->{links}}){
      $link->{'check_link'} = Sape::CheckLinks::yandex_check_url(
        $link->{'site_url'}.$link->{'page_uri'}
      );
    }
  }

} # загрузка данных по логину из локальной базы   


sub save_to_db {
  my $self = shift;
  eval{
    $self->{db}->clear;
    # TODO: это плохой метод, надо делать через UPDATE каждой ссылки
    $self->{db}->save( $self->{projects} );
  };
  die "DataBase error: $@" if $@;
} # сохранение данных по логину в локальной базе  
  # процедура опасная, поскольку сначала удаляются все данные
  # по пользователю, а затем записываются сохраненные из памяти


sub set_actions {
  my $self = shift;
  my $opts = shift;
  my @to_delete = @{$opts->{'delete'}};

  foreach my $pr (@{$self->{projects}}){
    foreach my $link (@{$pr->{links}}){
      $link->{'action'} = undef;
      foreach(@to_delete){
        $link->{'action'} = 'delete' if $link->{id} eq $_;
      }
    }
  }
  $self->save_to_db;
}


sub actions {
  my $self = shift;
  my @to_delete = 
    map{$_->{id}} 
    grep{$_->{action} eq 'delete'} 
    grep{defined $_->{action}}
    @{$self->links_list};
  return { 
    'delete' => \@to_delete,
    'accept' => [],
  };
} # список действий для выполнения через RPC интерфейс


sub update_with {
  my $self = shift;
  my $remote_user = shift;
  my $links_list = $self->links_list;
  foreach my $pr (@{$remote_user->{projects}}){
    foreach my $link (@{$pr->{links}}){
      my @old_links_with_same_id = 
          grep{$_->{id} == $link->{id}}
            @$links_list;

      # обновим не все (бывают проблемы с передачей данных - передаются пустые урлы)
      if(scalar @old_links_with_same_id == 1){
        my $old_link = $old_links_with_same_id[0];
        $link->{'is_indexed'} = $old_link->{'is_indexed'} if defined $old_link->{'is_indexed'};
        $link->{'site_url'} = $old_link->{'site_url'} unless $link->{'site_url'};
        $link->{'page_uri'} = $old_link->{'page_uri'} unless $link->{'page_uri'};
      }

      
    }
  }
  $self->{projects} = $remote_user->{projects};
} # обновление локальной базы ссылок из Sape.ru


sub check_links {
  my $self = shift;

  foreach my $pr (@{$self->{projects}}){
    foreach my $link (@{$pr->{links}}){
      my $uri = $link->{'site_url'} . $link->{'page_uri'};
      if(defined $link->{'is_indexed'}) {
        print "skipping $uri (", 
          ($link->{'is_indexed'})?'OK':'FAIL', ")\n" if $debug;
        next;
      }
      eval{
      $link->{'is_indexed'} = Sape::CheckLinks::check_qip($uri);
      };
      warn @$,"\n" if @$;
      print "$uri ... ", ($link->{'is_indexed'})?'OK':'FAIL', "\n" if $debug;
    }
  }
} # проверка всех ссылок логина

sub no_indexed_projects {
  my $self = shift;
  my $pr_arr = [];
  foreach my $pr (@{$self->{projects}}){
    my $pr_to_return = $pr;
    my @not_indexed_links = grep {not $_->{'is_indexed'}} @{$pr->{links}};
    $pr_to_return->{links} = \@not_indexed_links;
    push @$pr_arr, $pr_to_return;
  }
  return $pr_arr;
}



sub links_list {
  my $self = shift;
  my $links = [];

  foreach my $pr (@{$self->{projects}}){
    my @links_copy = @{$pr->{links}};
    push @$links, @links_copy;
  }
  return $links;
}



# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Sape - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Sape;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Sape, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

sergey, E<lt>sergey@suse.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by sergey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
