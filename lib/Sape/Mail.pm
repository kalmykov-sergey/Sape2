package Sape::Mail;

use strict;
use warnings;

use MIME::Lite;
use MIME::Words qw(:all);

sub notify {
    my ($user, $subj, $data) = @_;
    my $letter = MIME::Lite->new(
        From    => 'link@plarson.ru',
        To      => $user,
        Subject => encode_mimewords(
            $subj, 
            Charset=>'windows-1251', 
            Encoding=>'Q'
        ),
        Data => $data,
    );
    $letter->attr('content-type.charset' => 'windows-1251');
    $letter->send;
}


sub send_results {
    my ($user, $subj, $data, $file_name, $file) = @_;
    my $text = "Ğåçóëüòàòû ïğîâåğêè èíäåêñàöèè\n";
    my $letter = MIME::Lite->new(
        From    => 'link@plarson.ru',
        To      => $user,
        Subject => encode_mimewords(
            "RE: $subj", 
            Charset=>'windows-1251', 
            Encoding=>'Q'
        ),
        Type => 'multipart/mixed',
    );
    $letter->attr('content-type.charset' => 'windows-1251');
    
    my $part1 = MIME::Lite->new(
        Type => 'TEXT',
        Data => $data,
    );
    $part1->attr('content-type.charset' => 'Windows-1251');
    $letter->attach($part1);

    $letter->attach(
        Type        => 'application/vnd.ms-excel',
        Data        => $file,
        Filename    => $file_name,
        Disposition => 'attachment',
    );
    $letter->send();  
}


1;
