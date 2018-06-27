use Test::Most;
use Test::Warn;
use Test::MockModule;
use lib '/home/git/binary-com/perl-Data-Chronicle/lib';
use Data::Chronicle::Mock;
use App::Config::Chronicle;
use FindBin qw($Bin);

use constant {
    EMAIL_KEY    => 'system.email',
    FIRST_EMAIL  => 'abc@test.com',
    SECOND_EMAIL => 'def@test.com',
    THIRD_EMAIL  => 'ghi@test.com',
    ADMINS_KEY   => 'system.admins',
    ADMINS_SET   => ['john', 'bob', 'jane', 'susan'],
};

subtest 'Basic set and get' => sub {
    my $app_config = _new_app_config();

    ok $app_config->set({EMAIL_KEY() => FIRST_EMAIL}), 'Set 1 value succeeds';
    is $app_config->get(EMAIL_KEY), FIRST_EMAIL, 'Email is retrieved successfully';
};

subtest 'Batch set and get' => sub {
    my $app_config = _new_app_config();

    ok $app_config->set({
            EMAIL_KEY()  => FIRST_EMAIL,
            ADMINS_KEY() => ADMINS_SET
        }
        ),
        'Set 2 values succeeds';

    ok my @res = $app_config->get([EMAIL_KEY, ADMINS_KEY]);
    is $res[0],        FIRST_EMAIL, 'Email is retrieved successfully';
    is_deeply $res[1], ADMINS_SET,  'Admins is retrieved successfully';
};

subtest 'History chronicling' => sub {
    my $app_config = _new_app_config(cache_last_get_history => 1);
    my $module = Test::MockModule->new('Data::Chronicle::Reader');

    subtest 'Add history of values' => sub {
        # Sleeps ensure the chronicle records them at different times
        ok $app_config->set({EMAIL_KEY() => FIRST_EMAIL}), 'Set 1st value succeeds';
        sleep 1;
        ok $app_config->set({EMAIL_KEY() => SECOND_EMAIL}), 'Set 2nd value succeeds';
        sleep 1;
        ok $app_config->set({EMAIL_KEY() => THIRD_EMAIL}), 'Set 3rd value succeeds';
    };

    subtest 'Get history' => sub {
        is($app_config->get_history(EMAIL_KEY, 0), THIRD_EMAIL,  'History retrieved successfully');
        is($app_config->get_history(EMAIL_KEY, 1), SECOND_EMAIL, 'History retrieved successfully');
        is($app_config->get_history(EMAIL_KEY, 2), FIRST_EMAIL,  'History retrieved successfully');
    };

    subtest 'Ensure most recent get_history is cached (i.e. get_history should not be called)' => sub {
        $module->mock('get_history', sub { ok(0, 'get_history should not be called here') });
        is($app_config->get_history(EMAIL_KEY, 2), FIRST_EMAIL, 'Email retrieved via cache');
        $module->unmock('get_history');
    };

    subtest 'Check caching can be disabled' => sub {
        plan tests => 3;    # Ensures the ok check inside the mocked sub is run

        $app_config = _new_app_config_from_existing($app_config, cache_last_get_history => 0);
        $module->mock('get_history', sub { ok(1, 'get_history should be called here'); [FIRST_EMAIL] });
        is($app_config->get_history(EMAIL_KEY, 2), FIRST_EMAIL, 'Email retrieved via chronicle');
        $module->unmock('get_history');
    };
};

sub _new_app_config {
    my $app_config;
    my %options = @_;

    subtest 'Setup' => sub {
        my ($chronicle_r, $chronicle_w) = Data::Chronicle::Mock::get_mocked_chronicle();
        lives_ok {
            $app_config = App::Config::Chronicle->new(
                definition_yml   => "$Bin/test.yml",
                chronicle_reader => $chronicle_r,
                chronicle_writer => $chronicle_w,
                %options
            );
        }
        'We are living';
    };
    return $app_config;
}

sub _new_app_config_from_existing {
    my $new_app_config;
    my $old_app_config = shift;
    my %options        = @_;

    subtest 'Setup' => sub {
        lives_ok {
            $new_app_config = App::Config::Chronicle->new(
                definition_yml   => "$Bin/test.yml",
                chronicle_reader => $old_app_config->chronicle_reader,
                chronicle_writer => $old_app_config->chronicle_writer,
                %options
            );
        }
        'We are living';
    };
    return $new_app_config;
}

done_testing;
