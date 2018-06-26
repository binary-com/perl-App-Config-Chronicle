use Test::Most;
use Test::Warn;
use Test::MockModule;
use lib '/home/git/binary-com/perl-Data-Chronicle/lib';
use Data::Chronicle::Mock;
use App::Config::Chronicle;
use FindBin qw($Bin);

my $app_config;
my ($chronicle_r, $chronicle_w) = Data::Chronicle::Mock::get_mocked_chronicle();
lives_ok {
    $app_config = App::Config::Chronicle->new(
        definition_yml   => "$Bin/test.yml",
        chronicle_reader => $chronicle_r,
        chronicle_writer => $chronicle_w,
    );
}
'We are living';

done_testing;
