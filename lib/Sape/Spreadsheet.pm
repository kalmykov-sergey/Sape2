package Sape::Project::Spreadsheet;

use lib '/home/sergey/lib';
use strict;
use warnings;

use Spreadsheet::ParseExcel;
use Spreadsheet::WriteExcel;


sub parse_file {
    my $file = shift;
    my ($extension) = ($file =~ /\.([^.]*)$/);
    $extension = lc($extension);
    my @links = ();
    if($extension eq 'txt' or $extension eq 'csv'){
        chomp(@links = <$file>);
        s/\015// foreach(@links);
        s/\012// foreach(@links);
    } elsif ($extension eq 'xls') {
        @links = parse_xls($file);
    }
    return @links;
}


sub parse_xls {
    my $file = shift;
    my @links = ();
    my $cell_handler = sub {
        my $row         = $_[2];
        my $col         = $_[3];
        my $cell        = $_[4];

        return if $col > 1;
        my $value = $cell->value();
        if ($value =~ m#http://#){
            $value =~ s#http://##;
            push @links, $value;
        } 
    };# function for excel parsing
    my $excel_parser = Spreadsheet::ParseExcel->new(
        CellHandler => $cell_handler,
        NotSetCell  => 1
    );
    $excel_parser->Parse($file);
    return @links;
}

sub parse_donor {
    my $donor = shift;
    my $res = {};
    $res->{alexa_rank} = $1 if ($donor =~ /alexa_rank : (\d+)/);
    $res->{alexa_backsites} = $1 if ($donor =~ /alexa_backsites : (\d+)/);
    $res->{vis_day} = $1 if ($donor =~ /visitors_per_day : (\d+)/);
    return $res;
}

sub parse_donors {
    my $donors_ref = shift;
    my @rank = ();
    my @backsites = ();
    my @vis_day = ();
    foreach(keys %$donors_ref){
        my $site = $_;
        my $info = parse_donor($donors_ref->{$_});
        push @rank, $site if ($info->{alexa_rank} == 0 or $info->{alexa_rank} > 15_000_000); 
        push @backsites, $site if ($info->{alexa_backsites} < 10);
        push @vis_day, $site if ($info->{vis_day} < 10);
    }
    return (\@rank, \@backsites, \@vis_day);
}

sub result_to_csv_format_old {
    my ($links_ref, $donors_ref) = @_;
    my %bad_donors = %{$donors_ref};
    open my $fh, '>', \my $file or die "Failed to open filehandle: $!";
    print $fh "http://$_\n" foreach (sort @$links_ref);
    print $fh "\n;;\n"; 
    print $fh 'http://'.$_.(';'x8).join(';',split(/\n/,$bad_donors{$_}))."\n" foreach(keys %bad_donors);
    close $fh;
    return $file;
}

sub result_to_csv_format {
    my ($links_ref, $donors_ref) = @_;
    my ($rank, $backsites, $vis_day) = parse_donors($donors_ref);
    open my $fh, '>', \my $file or die "Failed to open filehandle: $!";
    my $num = scalar @$links_ref + scalar @$rank + scalar @$backsites + scalar @$vis_day;
    print $fh "not indexed;alexa_rank;alexa_backsites;LI_day_vis\n";
    for(0..$num){
        print $fh "http://".$links_ref->[$_] if ($links_ref->[$_]);
        print $fh ";http://".$rank->[$_] if ($rank->[$_]);
        print $fh ";http://".$backsites->[$_] if ($backsites->[$_]);
        print $fh ";http://".$vis_day->[$_] if ($vis_day->[$_]);
        print $fh "\n";
    }
    close $fh;
    return $file;
}


sub result_to_xls_format {
    my ($links_ref, $donors_ref) = @_;
    my %bad_donors = %{$donors_ref};

    open my $fh, '>', \my $file or die "Failed to open filehandle: $!";
    my $workbook = Spreadsheet::WriteExcel->new($fh);
    my $worksheet = $workbook->add_worksheet;
    my $i=1;
    $worksheet->write('A'.$i++, 'http://'.$_) foreach (sort @$links_ref);
    $i = $i + 2;
    foreach(keys %bad_donors){
        $worksheet->write('A'.$i, 'http://'.$_);
        foreach my $info (split(/\n/, $bad_donors{$_})){
            my $j = 0;
            $worksheet->write(chr(ord('I') + $j).$i, $info);
            $j++;
        }
        $i++;
    }
    $workbook->close;
    close $fh;
    return $file;
}

1;