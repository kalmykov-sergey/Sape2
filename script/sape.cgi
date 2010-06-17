#!"C:\xampp\perl\bin\perl.exe"
use lib 'C:/xampp/perl/projects';

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);

use Sape;
use Data::Dumper;

# authorization
my ($login, $password) = ('', '');
my ($cookie, $auth) = (undef, undef);

my $path = '/cgi-bin/sape_dump.cgi';

my $sape = Sape->new;
$auth = {connected => undef, path => $path, msg => 'Пожалуйста, авторизуйтесь'};
my $query = param('q');

# если уже есть куки..
if(my %sape = cookie('sape')){
  $login = $sape{login};
  $password = $sape{password};
  $sape->load($login, $password);
  $auth->{connected} = $sape->connected;
} # все, если есть только куки

# ... но если есть еще и пост-запрос на вход в систему ...
if(param('login') and param('action') eq 'Зайти'){
  $login = param('login');
  $password = param('password');
  $sape->load($login, $password);
  $auth->{msg} = "Здравствуйте, $login";
  $auth->{connected} = $sape->connected;
  if($auth->{connected}){    # установим куки
    my %hash = (login => $login, password => $password);
    $cookie = cookie(
      -name=>'sape',
      -value=> \%hash,
      -expires=>'+1y'
    );
  } else {
    $auth->{msg} = 'Неверный логин или пароль';
  }
}
# ... или пост-запрос на выход ...
if(param('action') eq 'Выйти'){
  $auth->{msg} = "До свидания, $login";
  ($login, $password) = ('', '');
  $sape = Sape->load($login, $password);
  $auth->{connected} = $sape->connected;
  $cookie = cookie(
    -name=>'sape',
    -value=> '',
    -expires=>'+1d',
  );
}



print header( 
    -type => 'text/html', 
    -charset => 'windows-1251', 
    -cookie => $cookie,
);
$sape->html($auth, $query);