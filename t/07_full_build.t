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

ok($app_config->system->isa('App::Config::Chronicle::Attribute::Section'), 'system is a Section');
is_deeply($app_config->system->admins, [], "admins is empty by default");
my $old_revision = $app_config->current_revision;
$app_config->system->email('test@abc.com');
$app_config->save_dynamic;
is_deeply($app_config->system->email, 'test@abc.com', "email is updated");
my $new_revision = $app_config->current_revision;
isnt($new_revision, $old_revision, "revision updated");
my $app_config2 = App::Config::Chronicle->new(
    definition_yml   => "$Bin/test.yml",
    chronicle_reader => $chronicle_r,
    chronicle_writer => $chronicle_w,
    refresh_interval => 1,
    cache_last_get_history => 1,
);
is($app_config2->current_revision, $new_revision,  "revision is correct even if we create a new instance");
is($app_config2->system->email,    'test@abc.com', "email is updated");
sleep 1; # Ensure the new entry is recorded at a different time
# force check & trigger internal timer
$app_config2->check_for_update;
$app_config->system->email('test2@abc.com');
$app_config->save_dynamic;
# will not refresh as not enough time has passed
$app_config2->check_for_update;
is($app_config2->system->email, 'test@abc.com', "still have old value");

sleep($app_config2->refresh_interval);
$app_config2->check_for_update;
is($app_config2->system->email, 'test2@abc.com', "check_for_update worked");

# Test get_history
is($app_config2->get_history('system.email', 0), 'test2@abc.com', 'History retrieved successfully');
is($app_config2->get_history('system.email', 1), 'test@abc.com', 'History retrieved successfully');

# Ensure most recent get_history is cached (i.e. get_history should not be called)
my $module = Test::MockModule->new('Data::Chronicle::Reader');
$module->mock('get_history', sub { ok(0, 'get_history should not be called here') });
is($app_config2->get_history('system.email', 1), 'test@abc.com', 'History retrieved successfully');
$module->unmock('get_history');

$app_config2->set({animal => 'cats', plant => 'trees'});

use Data::Dumper;
#warn Dumper($app_config2->get(['animal','plant']));



done_testing;
