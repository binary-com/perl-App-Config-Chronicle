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

subtest 'Global revision = 0' => sub {
    my $app_config = _new_app_config();
    is $app_config->global_revision(), 0, 'Brand new app config returns 0 revision';
};

subtest 'Keys' => sub {
    my $app_config = _new_app_config();
    my @keys       = $app_config->_keys();
    is_deeply \@keys, [EMAIL_KEY], 'Keys are listed correctly';
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

        $app_config = _new_app_config(cache_last_get_history => 0);
        $module->mock('get_history', sub { ok(1, 'get_history should be called here'); {data => FIRST_EMAIL} });
        is($app_config->get_history(EMAIL_KEY, 2), FIRST_EMAIL, 'Email retrieved via chronicle');
        $module->unmock('get_history');
    };
};

subtest 'Perl level caching' => sub {
    subtest "Chronicle shouldn't be engaged with perl caching enabled" => sub {
        my $app_config = _new_app_config(perl_level_caching => 1);

        my $reader_module = Test::MockModule->new('Data::Chronicle::Reader');
        $reader_module->mock('get',  sub { ok(0, 'get should not be called here') });
        $reader_module->mock('mget', sub { ok(0, 'mget should not be called here') });

        ok $app_config->set({EMAIL_KEY() => FIRST_EMAIL}), 'Set email without write to chron';
        is $app_config->get(EMAIL_KEY), FIRST_EMAIL, 'Email is retrieved without chron access';

        $reader_module->unmock('get');
        $reader_module->unmock('mget');
    };

    subtest 'Chronicle should be engaged with perl caching disabled' => sub {
        plan tests => 5;    # Ensures the ok checks inside the mocked subs are run

        my $app_config = _new_app_config(perl_level_caching => 0);

        my $reader_module = Test::MockModule->new('Data::Chronicle::Reader');
        $reader_module->mock('get',  sub { ok(1, 'get or mget should be called here'); {data => FIRST_EMAIL} });
        $reader_module->mock('mget', sub { ok(1, 'get or mgetshould be called here');  {data => FIRST_EMAIL} });
        my $writer_module = Test::MockModule->new('Data::Chronicle::Writer');
        $writer_module->mock('set',  sub { ok(1, 'set or sget should be called here') });
        $writer_module->mock('mset', sub { ok(1, 'set or sget should be called here') });

        ok $app_config->set({EMAIL_KEY() => FIRST_EMAIL}), 'Set email with write to chron';
        is $app_config->get(EMAIL_KEY), FIRST_EMAIL, 'Email is retrieved with chron access';

        $reader_module->unmock('get');
        $writer_module->unmock('set');
        $reader_module->unmock('mget');
        $writer_module->unmock('mset');
    };
};

subtest 'Global revision updates' => sub {
    my $app_config = _new_app_config(cache_last_get_history => 1);
    my $old_rev = $app_config->global_revision();

    ok $app_config->set({EMAIL_KEY() => FIRST_EMAIL}), 'Set 1 value succeeds';

    my $new_rev = $app_config->global_revision();
    ok $new_rev > $old_rev, 'Revision was increased';
};

subtest 'Cache syncing' => sub {
    my $cached_config1 = _new_app_config(perl_level_caching => 1);
    my $cached_config2 = _new_app_config(perl_level_caching => 1);
    my $direct_config  = _new_app_config(perl_level_caching => 0);

    ok $direct_config->set({EMAIL_KEY() => FIRST_EMAIL}), 'Set email succeeds';
    is $direct_config->get(EMAIL_KEY), FIRST_EMAIL, 'Email is retrieved successfully';
    is $cached_config1->get(EMAIL_KEY), undef, 'Cache1 is empty';
    is $cached_config2->get(EMAIL_KEY), undef, 'Cache2 is empty';

    ok $cached_config1->update_cache(), 'Cache 1 is updated';
    ok $cached_config2->update_cache(), 'Cache 2 is updated';
    is $cached_config1->get(EMAIL_KEY), FIRST_EMAIL, 'Cache1 is updated with email';
    is $cached_config2->get(EMAIL_KEY), FIRST_EMAIL, 'Cache2 is updated with email';

    sleep 1; #Ensure new value is recorded at a different time
    ok $cached_config1->set({EMAIL_KEY() => SECOND_EMAIL}), 'Set email via cache 1 succeeds';
    is $direct_config->get(EMAIL_KEY), SECOND_EMAIL, 'Email is retrieved directly';
    is $cached_config1->get(EMAIL_KEY), SECOND_EMAIL, 'Cache1 has updated email';
    is $cached_config2->get(EMAIL_KEY), FIRST_EMAIL, 'Cache2 still has old email';
    
    ok $cached_config2->update_cache(), 'Cache 2 is updated';
    is $cached_config2->get(EMAIL_KEY), SECOND_EMAIL, 'Cache2 has updated email';
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

done_testing;
