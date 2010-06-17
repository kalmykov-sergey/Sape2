package Sape::Index;
use strict;
use warnings;

use Carp;
use LWP::UserAgent;
use URI;
use URI::Escape;
use HTML::Entities;

use lib '..';
use Sape::Index::Alexa;
use Sape::Index::LiveInternet;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

our @EXPORT = qw(
    is_bad_donor
    qip_check_url
    yandex_check_url
    qip_check
    yandex_check    
);

our $VERSION = '0.01';


our $UA = LWP::UserAgent->new();

sub is_bad_donor {
    my $link = shift;
    my ($desc, %alexa, $li);
    eval{ %alexa = alexa_stats($link) };
    $desc .= "problem with alexa: $@\n" if $@;
    eval{ $li = live_internet_stats($link) };
    $desc .= "problem with liveinternet: $@\n" if $@;

    $desc .= ("alexa rank is low (".$alexa{rank}.")\n") if(%alexa and $alexa{rank} > 15_000_000);
    $desc .= ("alexa rank is null\n") if(%alexa and $alexa{rank} == 0);
    $desc .= ("too few alexa sites (" .$alexa{sites} . ")\n") if(%alexa and $alexa{sites} < 10);
    $desc .= ("too few visitors (" .$li->{day_vis} . " per day)\n") if($li and $li->{site} and $li->{day_vis} < 10);
    return $desc;
}


sub qip_check_url {
    my $link = shift;
    $link =~ s{^https?://}{};
    $link =~ s{^www\.}{};
    my $url = 'http://search.qip.ru/search?query='.uri_escape("http://".$link);
    return $url;
}


sub qip_check {
    my $link = shift;
    $link =~ s{\s+$}{};
    $link =~ s{^https?://}{}i;
    $link =~ s{^www\.}{}i;
    $link =~ s{\/$}{}i;

    my $uri = URI->new("http://search.qip.ru/search");
    my @links = ("http://$link", "http://www.$link");
    foreach my $link (@links){
        $uri->query_form(
                         query => $link
                         );
        my $resp = $UA->get($uri->as_string);
        croak($resp->status_line) unless $resp->is_success;
        my $html = lc $resp->content;
        my $match = lc uri_unescape(encode_entities($link));
        $match =~ s{\s+$}{}g;
        return 1 if (
                     index($html,'<ol class="searchresult"') > -1
                     and
                     index($html, '<p class="info">'.$match) > -1
                     )
    }
    return 0;
}


sub yandex_check_url {
    my $link = shift;
    $link =~ s{^https?://}{};
    $link =~ s{^www\.}{};
    my $url = 'http://yandex.ru/yandsearch?text='.uri_escape("url:$link | url:www.$link"). '&lr=1';
    return $url;
}


sub yandex_check {
    my $link = shift;
    $link =~ s{^https?://}{}i;
    $link =~ s{^www\.}{}i;
    $link =~ s{\/$}{}i;

    my $uri = URI->new("http://yandex.ru/yandsearch");
    $uri->query_form(
                     text => "url:$link | url:www.$link",
                     lr => 1,
                     );
    my $resp = $UA->get($uri->as_string);
    croak($resp->status_line) unless $resp->is_success;
    my $html = lc $resp->content;
    croak("CAPTCHA") if ($html =~ m/captcha\.yandex\.net/i);
    return 1 if (index($html,'div class="fe"') > -1 and index($html,'div class="hp"') == -1);
    return 0;
}


1;

__END__
=pod
=cut