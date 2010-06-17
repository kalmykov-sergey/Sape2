#!/usr/bin/perl -w

use lib '/home/sergey/lib';
use strict;

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);
use DBI;
use BackLinks;
use Time::HiRes qw(time);
use URI::Escape;

my $time0 = time();

sub apache_fork {
    my ($func, $redirect) = @_;
    defined(my $pid = fork) or die "Cannot fork: $!";
    if($pid){
        print redirect($redirect);
        exit;
    } else {
        close STDOUT;
        close STDIN;
        close STDERR;
        open(STDOUT, ">/dev/null");
        open(STDIN, "<dev/null");
        open(STDERR, ">>/home/sergey/html/error.log");
        &{$func};
    }
} # запуск фоновой процедуры при редиректе

sub apache_recheck_read {
    open my $r, '</home/sergey/html/to_recheck' or die;
    my $file_id = <$r>;
    close $r;
    BackLinks::recheck_file($file_id);
}

sub apache_recheck_write {
    my $file_id = shift;
    open my $w, '>/home/sergey/html/to_recheck' or die;
    print $w $file_id;    
    close $w;
    apache_fork(\&apache_recheck_read, "http://mail.plarson.ru:81/cgi-bin/monitor.cgi?file=$file_id");
}

# MAIN

my $user = cookie('user');

my $upload_info = 'Выберите файл для загрузки';
if(my $file = param('upload')){
    my $mime_type = uploadInfo($file)->{'Content-Type'};
    if(-s $file > 1024*1024){
        $upload_info = "$file слишком большой: ".int((-s $file)/1024)."KB";
    } elsif(my @links = BackLinks::File::parse_file($file)){
        my $engine = param('engine') || 'qip';
        $file =~ s/\.[^.]*$//i;
        my $file_id = BackLinks::file_to_db(\@links, $file,
                user => $user || 'anonymous',
                mime_type => $mime_type,
                engine => $engine,
        );
        my $redirect = "http://mail.plarson.ru:81/cgi-bin/monitor.cgi?file=$file_id";
        apache_fork(\&BackLinks::check_last_file, $redirect); 
        # передача параметра в процедуру почему-то 
        # не дает апачу закрыть соединение, см. apache_fork()
        # поэтому проверяем ПРИНЦИПИАЛЬНО последний файл
    } else {
        $upload_info = "Извините, не могу обработать $file ($mime_type)";
    }
}

=pod
BackLinks::Sape::login('kalmykov', 'kalmykov1A');
my $sape_info = 'Выберите проект для проверки ссылок';
my %sape_hash = reverse %{BackLinks::Sape::get_projects()};
my @sape_arr = keys %sape_hash;
if(my $sape_project_id = param('sape_project')){
    my $engine = param('engine') || 'qip';
    my $links = BackLinks::Sape::get_links($sape_project_id);
    my $file_id = BackLinks::file_to_db($links, $sape_hash{$sape_project_id},
                user => $user || 'anonymous',
                mime_type => 'xml from sape :)',
                engine => $engine,
        );
        my $redirect = "http://mail.plarson.ru:81/cgi-bin/monitor.cgi?file=$file_id";
        apache_fork(\&BackLinks::check_last_file, $redirect); 
}

=cut

my %password = (
    'chpi_rf@mail.ru' => 'chpi_rf@mail.ru',
    'lavan@mail.ru' => 'lavan@mail.ru',
    'kalmykov.sergei@gmail.com' => '1234',
);


my $cookie;

if(my $set_user = param('user')){
    my $pass = param('pass');
    if(
        (length($pass) > 0 and $pass eq $password{$set_user})
        or ($user)
    ){
        $cookie = cookie(
            -name=>'user',
            -value=>$set_user || $user,
            -expires=>'+1y'
        );
        $user = $set_user;
    }
}

if(my $file_to_delete = param('delete')){
    BackLinks::delete_file($file_to_delete);
}

if(my $file_to_recheck = param('recheck')){
    apache_recheck_write($file_to_recheck);
}

my @files;
my $diag;
if($user){
    my $time1 = time();
    my $dbh = DBI->connect('dbi:mysql:seo:localhost', 'seo', 'seo2009');
    my $q_files = $dbh->prepare("
        select id, name, engine, time from backlinks_files 
        where invisible=0 order by id desc
    ");
    $q_files->execute;
    my $time2 = time();
    @files = (th(['Файл', 'процент проверенного', 'скачать результат', 'когда был загружен', 'удалить', 'проверить']));
    while(my $row = $q_files->fetchrow_hashref){
        my $start = time();
        my $all = $dbh->selectrow_hashref("
            select count(id) as num from backlinks_links 
            where file_id = ?
        ", undef, $row->{id})->{num};
        my $checked = $dbh->selectrow_hashref("
            select count(backlinks_links.id) as num from 
                backlinks_links join backlinks_check 
                on backlinks_links.id = backlinks_check.link_id 
            where backlinks_links.file_id = ?    
        ", undef, $row->{id})->{num};
        my $finish = time();
        my $download_link = '';
        $download_link = '<a href="get.cgi?file='.$row->{id}.'&type=csv">CSV</a>'.
          '&nbsp; &nbsp;<a href="get.cgi?file='.$row->{id}.'&type=xls">XLS</a>'
          if($checked == $all);
        push @files, td([
          '<a href="monitor.cgi?file='.
            $row->{id}.'">'.$row->{name}.'</a>',
          "$checked/$all (".int(100*$checked/$all).'%)',
          $download_link,
          $row->{time},
          ($checked==$all)?'<a href="view.cgi?delete='.$row->{id}.'">удалить</a>':'',
          ($checked==$all)?'<a href="view.cgi?recheck='.$row->{id}.'">перепроверить</a>':'',
        ]);
        
        $diag .= " + ".($finish-$start);
    }
    $dbh->disconnect;
    my $time3 = time();
    $diag = "Обращение к mysql: ".($time2-$time1)." + ".($time3 - $time2) . "($diag) сек, ";
}

my $upload_form = h2('Загрузить файл').
    start_multipart_form(-style => 'width:220px;').
    filefield('upload'). br.
    'Поисковик:'. br. radio_group('engine', [qw{qip yandex xml}],'qip'). br.
    submit(-name => 'Загрузить файл'). br. $upload_info. end_form;

=pod
my $sape_form = h2('Проект Sape').
    start_multipart_form(-style => 'width:220px;').
    submit(-name => 'Проверить ссылки'). br. 
            popup_menu(
#                -onChange => 'submit()',
                -name => 'sape_project',
                -values => [@sape_arr],
                -labels => \%sape_hash,
                -default => '',
            ).
     br. $sape_info. end_form;
=cut
my $time4 = time();
$diag .= ' вся страница: '. ($time4-$time0);

print header( -type => 'text/html', -charset => 'windows-1251', -cookie => $cookie);
print table({-width => '100%'}, Tr ( 
td({-valign => 'top'},
    table({-cellpadding => '10px', width => '100%'},undef, $user?Tr({},\@files):'')
), 
td({-valign => 'top', width => '220px'}, 
    '<a href="../link_robot_help.html">Помощь</a>', br,
    #h4($diag),
    # авторизационная форма
    h2('Авторизация'),
    start_multipart_form(-style => 'width:220px;'), 
    $user?textfield(-name => 'user', -value => "$user"):textfield('user'),
    'e-mail', br, 
    password_field('pass'), 'пароль', br,
    submit(-name => 'Подтвердить'), end_form,
    # форма загрузки файла
    $user?$upload_form:''
#    $user?$sape_form:''
)
));


