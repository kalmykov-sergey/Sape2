package Sape::HTML;

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);
use Template;

use Data::Dumper;


sub new {
  my $class = shift;

  my $template = Template->new({
    INCLUDE_PATH => 'Sape/templates',
  });

=pod
  # ������ ��� �� �����, ��������� �� ��������� ��� ���� 
  my $path = $0;
  $path =~ s{\/}{/}gs; # ��� windows
  $path =~ s{.*/cgi-bin}{/cgi-bin};
=cut

  my $self = {
    tt => $template, 
#    path => $path
  };
  bless $self, $class;
  $self->cgi_auth();
#  die Dumper $self;
  return $self;
} # �����������, �������������� => �������������� ����� � ����� ��������


=pod
    ����� ��������� - ��� ������� ������ 'module', ������� ���������� �����
    '/cgi-bin/module.cgi' ���� 
    ��������� ����� 'sub module' � �������� 'module.html' 
    � �����-���������� 'sub cgi_module' (������, ���������� ����� ��������
    � � ��� cgi-����)

    � ����� '/cgi-bin/module.cgi' ��������� ���������� ��������
    Sape->cgi('module');
    � ��������� ����� ��������
    Sape->html('module');
=cut

sub cgi {
  my $self = shift;
  my $module = shift;
  $module = "cgi_".$module;
  $self->$module();
}


sub html {
  my $self = shift;
  my $module = shift;

  my $stash = $self->$module();
  $stash->{'function_name'} = $module;
  $self->process($stash);
} # ������������ ������� �� ����� (dispatcher)


sub process {
  my $self = shift;
  my $stash = shift;

  my $name = $stash->{'function_name'};
  $stash->{basefilepath} = "/cgi-bin/$name.cgi" unless $stash->{basefilepath};
  
  print header( 
      -type => 'text/html', 
      -charset => 'windows-1251', 
      -cookie => $self->{cookie},
  );

=pod
  # �������� ������� �� ��, ��� � � ���������� �������, ���� ���� �� �����
  my @intro = caller(1);
  $name = $intro[3];
  $name =~ s{.*::}{}gs;

  $stash->{'basefilepath'} = $self->{path};
=cut

  $self->{tt}->process("$name.html", $stash) or die $self->{tt}->error();
}



### ����������� ###

sub cgi_auth {
  my $self = shift;

  $self->{auth}{msg} = '����������, �������������';

  # ���� ��� ���� ����..
  if(my %sape = cookie('sape')){
    $login = $sape{login};
    $password = $sape{password};
    $self->{sape} = Sape->new($login, $password);
    $self->{auth}{msg} = '';
  } # ���, ���� ���� ������ ����

  # ... �� ���� ���� ��� � ����-������ �� ���� � ������� ...
  if(param('login') and param('action') eq '�����'){
    $login = param('login');
    $password = param('password');
    eval{
      $self->{sape} = Sape->new($login, $password);
    };
    unless($@){ # ����������� ��������, ������� ����
      $self->{auth}{msg} = "������������, $login";
      my %hash = (login => $login, password => $password);
      $self->{cookie} = cookie(
        -name=>'sape',
        -value=> \%hash,
        -expires=>'+1y'
      );
    } else {
      $auth->{msg} = $@;
    }
  
  # ... ��� ����-������ �� ����� ...
  } elsif (param('action') eq '�����'){
    $self->{auth}{msg} = "�� ��������, ".$self->{sape}{user}{login};
    $self->{sape} = {};
    $self->{cookie} = cookie(
      -name=>'sape',
      -value=> '',
      -expires=>'+1d',
    );
  }

} # �����������


sub auth {
  my $self = shift;
  my $stash = {
    user => $self->{sape}{user},
    auth => $self->{auth},
    authorized => defined $self->{sape}{user}{login},
  };
  
  return $stash;
} # ����� ��� �����������


### ������� ###

sub cgi_projects {
  my $self = shift;

  $self->{query} = {
    project => param('project') || undef, 
    filter => param('filter') || undef,
    mode => param('mode') || undef,
  };
  
  if($self->{query}{mode} eq 'modify' or $self->{query}{mode} eq 'delete'){
    $self->cgi('modify');
    $self->html('modify');
    exit;
  }

  if($self->{query}{mode} eq 'register'){
    $self->cgi('register');
    $self->html('register');
    exit;
  }
#  die Dumper $self;
}

sub projects {
  my $self = shift;

  my $stash = {projects => $self->{sape}{projects}};

  if($self->{query}){
    if($self->{query}{project}){
      @{$stash->{projects}} = grep{$_->{name} eq $self->{query}{project}} @{$stash->{projects}};
    }
    
    if($self->{query}{filter} eq 'noindex'){
      foreach my $pr (@{$stash->{projects}}){
        @{$pr->{links}} = grep{$_->{'is_indexed'} == 0} @{$pr->{links}};
      }
    }
  }

  return $stash;
}


sub cgi_modify {
  my $self = shift;

  if(param('action') eq '��������'){
    my @to_delete = param('to_delete');
    $self->{sape}->set_actions({'delete' => \@to_delete});
    print redirect("sape.cgi");
    exit;
  }

}


sub modify {
  my $self = shift;

  my $stash = {projects => $self->{sape}{projects}};
  $stash->{basefilepath} = '/cgi-bin/sape.cgi';

  if($self->{query}{project}){
    @{$stash->{projects}} = grep{$_->{name} eq $self->{query}{project}} @{$stash->{projects}};
  }
  
  if($self->{query}{filter} eq 'noindex'){
    foreach my $pr (@{$stash->{projects}}){
      @{$pr->{links}} = grep{$_->{'is_indexed'} == 0} @{$pr->{links}};
    }
  }
  
  return $stash;
}


sub register {
  my $self = shift;

  my $stash = {basefilepath => '/cgi-bin/sape.cgi'};

  return $stash;
}


sub cgi_register {
  my $self = shift;

  if(param('action') eq '�����������'){
    my $login = param('register_login');
    my $password = param('register_password');
    eval{
      my $id = Sape::RPC->login($login, $password);
    };
    if($@){
      die "����������� ����������: $@";
    } else {
      Sape->register_new_user($login, $password);
      print redirect('sape.cgi');
      exit;
    }
  }
}

sub test {   
  my $self = shift;

  my $stash = {hello => 'hello'};
  my %merged = (%$stash, %{$self->auth});
  
  return \%merged;
}


sub sape {
  my $self = shift;

  my $stash = {hello => 'hello'};
  my %merged = (%$stash, %{$self->auth}, %{$self->projects});
  
  return \%merged;
}

1;