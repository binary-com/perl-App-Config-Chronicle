# NAME

App::Config::Chronicle - An OO configuration module which can be changed and stored into chronicle database.

# SYNOPSIS

    my $app_config = App::Config::Chronicle->new;

# DESCRIPTION

This module parses configuration files and provides interface to access
configuration information.

# FILE FORMAT

The configuration file is a YAML file. Here is an example:

    system:
      description: "Various parameters determining core application functionality"
      isa: section
      contains:
        email:
          description: "Dummy email address"
          isa: Str
          default: "dummy@mail.com"
          global: 1
        refresh:
          description: "System refresh rate"
          isa: Num
          default: 10
          global: 1
        admins:
          description: "Are we on Production?"
          isa: ArrayRef
          default: []

Every attribute is very intuitive. If an item is global, you can change its value and the value will be stored into chronicle database by calling the method `save_dynamic`.

# SUBROUTINES/METHODS (LEGACY)

## REDIS\_HISTORY\_TTL

The maximum length of time (in seconds) that a cached history entry will stay in Redis.

## definition\_yml

The YAML file that store the configuration

## chronicle\_reader

The chronicle store that configurations can be fetch from it. It should be an instance of [Data::Chronicle::Reader](https://metacpan.org/pod/Data%3A%3AChronicle%3A%3AReader).
But user is free to implement any storage backend he wants if it is implemented with a 'get' method.

## chronicle\_writer

The chronicle store that updated configurations can be stored into it. It should be an instance of [Data::Chronicle::Writer](https://metacpan.org/pod/Data%3A%3AChronicle%3A%3AWriter).
But user is free to implement any storage backend he wants if it is implemented with a 'set' method.

## chronicle\_subscriber

The chronicle connection that can notify via callbacks when particular configuration items have a new value set. It should be an instance of [Data::Chronicle::Subscriber](https://metacpan.org/pod/Data%3A%3AChronicle%3A%3ASubscriber).

## refresh\_interval

How much time (in seconds) should pass between [check\_for\_update](https://metacpan.org/pod/check_for_update) invocations until
it actually will do (a bit heavy) lookup for settings in redis.

Default value is 10 seconds

## check\_for\_update

check and load updated settings from chronicle db

Checks at most every `refresh_interval` unless forced with
a truthy first argument

## save\_dynamic

Save dynamic settings into chronicle db

## current\_revision

Loads setting from chronicle reader and returns the last revision

It is more likely that you want ["loaded\_revision"](#loaded_revision) in regular use

## loaded\_revision

Returns the revision loaded and served by this instance

This may not reflect the latest stored version in the Chronicle persistence.
However, it is the revision of the data which will be returned when
querying this instance

# SUBROUTINES/METHODS
######################################################
###### Start new API
######################################################

## local\_caching

If local\_caching is set to the true then key-value pairs stored in Redis will be cached locally.

Calling update\_cache will update the local cache with any changes from Redis.
refresh\_interval defines (in seconds) the minimum time between seqequent updates.

Calls to get on this object will only ever access the cache.
Calls to set on this object will immediately update the values in the local cache and Redis.

## update\_cache

Loads latest values from data chronicle into local cache.
Calls to this method are rate-limited by `refresh_interval`.

## global\_revision

Returns the global revision version of the config chronicle.
This will correspond to the last time any of values were changed.

## set

Takes a hashref of key->value pairs and atomically sets them in config chronicle

Example:
    set({key1 => 'value1', key2 => 'value2', key3 => 'value3',...});

## get

Takes either
    - an arrayref of keys, gets them atomically, and returns a hashref of key->values,
    including the global\_revision under the key '\_global\_rev'.
    - a single key (as a string), gets the value, and returns it directly.
If a key has an empty value, it will return with undef.

For convenience a get with just a key string will return the value only.

Example:
    get(\['key1','key2','key3',...\]);
Returns:
    {'key1' => 'value1', 'key2' => 'value2', 'key3' => 'value3',..., '\_global\_rev' => '&lt;number>'}

Example:
    get(\['key1'\]);
Returns:
    {'key1' => 'value1', '\_global\_rev' => '&lt;number>'}

Example:
    get('key1');
Returns:
    'value1'

## get\_history

Retreives a past revision of an app config entry, where $rev is the number of revisions in the past requested.
If the optional third argument is true then result of the query will be cached in Redis. This is useful if a certain
    revision will be needed repeatedly, to avoid excessive database access. By default this argument is 0.
All cached revisions will become stale if the key is set with a new value.

Example:
    get\_history('system.email', 0); Retrieves current version
    get\_history('system.email', 1); Retreives previous revision
    get\_history('system.email', 2); Retreives version before previous

## subscribe

Subscribes to changes for the specified $key with the sub $subref called when a new value is set.
The chronicle\_writer must have publish\_on\_set enabled.

## unsubscribe

Stops the sub $subref from being called when $key is set with a new value.
The chronicle\_writer must have publish\_on\_set enabled.

## all\_keys

Returns a list containing all keys in the config chronicle schema

## dynamic\_keys

Returns a list containing only the dynamic keys in the config chronicle schema

## static\_keys

Returns a list containing only the static keys in the config chronicle schema

## get\_data\_type

Returns the data type associated with a particular key

## get\_default

Returns the default value associated with a particular key

## get\_description

Returns the default value associated with a particular key

## get\_key\_type

Returns the key type associated with a particular key

## BUILD

# AUTHOR

Binary.com, `<binary at cpan.org>`

# BUGS

Please report any bugs or feature requests to `bug-app-config at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Config](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Config).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Config::Chronicle

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Config](http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Config)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/App-Config](http://annocpan.org/dist/App-Config)

- CPAN Ratings

    [http://cpanratings.perl.org/d/App-Config](http://cpanratings.perl.org/d/App-Config)

- Search CPAN

    [http://search.cpan.org/dist/App-Config/](http://search.cpan.org/dist/App-Config/)

# ACKNOWLEDGEMENTS
