local data = {}

data.header = [[
---
title: Configuration Reference
#
#  WARNING: this file was auto-generated by a script.\n")
#  DO NOT edit this file directly. Instead, send a pull request to change\n")
#  the files in https://github.com/Kong/docs.konghq.com/tree/master/autodoc-conf\n")
#
---

## Configuration loading

Kong comes with a default configuration file that can be found at
`/etc/kong/kong.conf.default` if you installed Kong via one of the official
packages. To start configuring Kong, you can copy this file:

```bash
$ cp /etc/kong/kong.conf.default /etc/kong/kong.conf
```

Kong will operate with default settings should all the values in your
configuration be commented out. Upon starting, Kong looks for several
default locations that might contain a configuration file:

```
/etc/kong/kong.conf
/etc/kong.conf
```

You can override this behavior by specifying a custom path for your
configuration file using the `-c / --conf` argument in the CLI:

```bash
$ kong start --conf /path/to/kong.conf
```

The configuration format is straightforward: simply uncomment any property
(comments are defined by the `#` character) and modify it to your needs.
Boolean values can be specified as `on`/`off` or `true`/`false` for convenience.

## Verifying your configuration

You can verify the integrity of your settings with the `check` command:

```bash
$ kong check <path/to/kong.conf>
configuration at <path/to/kong.conf> is valid
```

This command will take into account the environment variables you have
currently set, and will error out in case your settings are invalid.

Additionally, you can also use the CLI in debug mode to have more insight
as to what properties Kong is being started with:

```bash
$ kong start -c <kong.conf> --vv
2016/08/11 14:53:36 [verbose] no config file found at /etc/kong.conf
2016/08/11 14:53:36 [verbose] no config file found at /etc/kong/kong.conf
2016/08/11 14:53:36 [debug] admin_listen = "0.0.0.0:8001"
2016/08/11 14:53:36 [debug] database = "postgres"
2016/08/11 14:53:36 [debug] log_level = "notice"
[...]
```

## Environment variables

When loading properties out of a configuration file, Kong will also look for
environment variables of the same name. This allows you to fully configure Kong
via environment variables, which is very convenient for container-based
infrastructures, for example.

To override a setting using an environment variable, declare an environment
variable with the name of the setting, prefixed with `KONG_` and capitalized.

For example:

```
log_level = debug # in kong.conf
```

can be overridden with:

```bash
$ export KONG_LOG_LEVEL=error
```

## Injecting Nginx directives

Tweaking the Nginx configuration of your Kong instances allows you to optimize
its performance for your infrastructure.

When Kong starts, it builds an Nginx configuration file. You can inject custom
Nginx directives to this file directly via your Kong configuration.

### Injecting individual Nginx directives

Any entry added to your `kong.conf` file that is prefixed by `nginx_http_`,
`nginx_proxy_` or `nginx_admin_` will be converted into an equivalent Nginx
directive by removing the prefix and added to the appropriate section of the
Nginx configuration:

- Entries prefixed with `nginx_http_` will be injected to the overall `http`
block directive.

- Entries prefixed with `nginx_proxy_` will be injected to the `server` block
directive handling Kong's proxy ports.

- Entries prefixed with `nginx_admin_` will be injected to the `server` block
directive handling Kong's Admin API ports.

For example, if you add the following line to your `kong.conf` file:

```
nginx_proxy_large_client_header_buffers=16 128k
```

it will add the following directive to the proxy `server` block of Kong's
Nginx configuration:

```
    large_client_header_buffers 16 128k;
```

Like any other entry in `kong.conf`, these directives can also be specified
using [environment variables](#environment-variables) as shown above. For
example, if you declare an environment variable like this:

```bash
$ export KONG_NGINX_HTTP_OUTPUT_BUFFERS="4 64k"
```

This will result in the following Nginx directive being added to the `http`
block:

```
    output_buffers 4 64k;
```

As always, be mindful of your shell's quoting rules specifying values
containing spaces.

For more details on the Nginx configuration file structure and block
directives, see https://nginx.org/en/docs/beginners_guide.html#conf_structure.

For a list of Nginx directives, see https://nginx.org/en/docs/dirindex.html.
Note however that some directives are dependent of specific Nginx modules,
some of which may not be included with the official builds of Kong.

### Including files via injected Nginx directives

For more complex configuration scenarios, such as adding entire new
`server` blocks, you can use the method described above to inject an
`include` directive to the Nginx configuration, pointing to a file
containing your additional Nginx settings.

For example, if you create a file called `my-server.kong.conf` with
the following contents:

```
# custom server
server {
  listen 2112;
  location / {
    # ...more settings...
    return 200;
  }
}
```

You can make the Kong node serve this port by adding the following
entry to your `kong.conf` file:

```
nginx_http_include = /path/to/your/my-server.kong.conf
```

or, alternatively, by configuring it via an environment variable:

```bash
$ export KONG_NGINX_HTTP_INCLUDE="/path/to/your/my-server.kong.conf"
```

Now, when you start Kong, the `server` section from that file will be added to
that file, meaning that the custom server defined in it will be responding,
alongside the regular Kong ports:

```bash
$ curl -I http://127.0.0.1:2112
HTTP/1.1 200 OK
...
```

Note that if you use a relative path in an `nginx_http_include` property, that
path will be interpreted relative to the value of the `prefix` property of
your `kong.conf` file (or the value of the `-p` flag of `kong start` if you
used it to override the prefix when starting Kong).

## Custom Nginx templates & embedding Kong

For the vast majority of use-cases, using the Nginx directive injection system
explained above should be sufficient for customizing the behavior of Kong's
Nginx instance. This way, you can manage the configuration and tuning of your
Kong node from a single `kong.conf` file (and optionally your own included
files), without having to deal with custom Nginx configuration templates.

There are two scenarios in which you may want to make use of custom Nginx
configuration templates directly:

- In the rare occasion that you may need to modify some of Kong's default
Nginx configuration that are not adjustable via its standard `kong.conf`
properties, you can still modify the template used by Kong for producing its
Nginx configuration and launch Kong using your customized template.

- If you need to embed Kong in an already running OpenResty instance, you
can reuse Kong's generated configuration and include it in your existing
configuration.

### Custom Nginx templates

Kong can be started, reloaded and restarted with an `--nginx-conf` argument,
which must specify an Nginx configuration template. Such a template uses the
[Penlight][Penlight] [templating engine][pl.template], which is compiled using
the given Kong configuration, before being dumped in your Kong prefix
directory, moments before starting Nginx.

The default template can be found at:
https://github.com/kong/kong/tree/master/kong/templates. It is split in two
Nginx configuration files: `nginx.lua` and `nginx_kong.lua`. The former is
minimalistic and includes the latter, which contains everything Kong requires
to run. When `kong start` runs, right before starting Nginx, it copies these
two files into the prefix directory, which looks like so:

```
/usr/local/kong
├── nginx-kong.conf
└── nginx.conf
```

If you must tweak global settings that are defined by Kong but not adjustable
via the Kong configuration in `kong.conf`, you can inline the contents of the
`nginx_kong.lua` configuration template into a custom template file (in this
example called `custom_nginx.template`) like this:

```
# ---------------------
# custom_nginx.template
# ---------------------

worker_processes ${{ "{{NGINX_WORKER_PROCESSES" }}}}; # can be set by kong.conf
daemon ${{ "{{NGINX_DAEMON" }}}};                     # can be set by kong.conf

pid pids/nginx.pid;                      # this setting is mandatory
error_log logs/error.log ${{ "{{LOG_LEVEL" }}}}; # can be set by kong.conf

events {
    use epoll;          # a custom setting
    multi_accept on;
}

http {

  # contents of the nginx_kong.lua template follow:

  resolver ${{ "{{DNS_RESOLVER" }}}} ipv6=off;
  charset UTF-8;
  error_log logs/error.log ${{ "{{LOG_LEVEL" }}}};
  access_log logs/access.log;

  ... # etc
}
```

You can then start Kong with:

```bash
$ kong start -c kong.conf --nginx-conf custom_nginx.template
```

## Embedding Kong in OpenResty

If you are running your own OpenResty servers, you can also easily embed Kong
by including the Kong Nginx sub-configuration using the `include` directive.
If you have an existing Nginx configuration, you can simply include the
Kong-specific portion of the configuration which is output by Kong in a separate
`nginx-kong.conf` file:

```
# my_nginx.conf

# ...your nginx settings...

http {
    include 'nginx-kong.conf';

    # ...your nginx settings...
}
```

You can then start your Nginx instance like so:

```bash
$ nginx -p /usr/local/openresty -c my_nginx.conf
```

and Kong will be running in that instance (as configured in `nginx-kong.conf`).

## Serving both a website and your APIs from Kong

A common use case for API providers is to make Kong serve both a website
and the APIs themselves over the Proxy port &mdash; `80` or `443` in
production. For example, `https://example.net` (Website) and
`https://example.net/api/v1` (API).

To achieve this, we cannot simply declare a new virtual server block,
like we did in the previous section. A good solution is to use a custom
Nginx configuration template which inlines `nginx_kong.lua` and adds a new
`location` block serving the website alongside the Kong Proxy `location`
block:

```
# ---------------------
# custom_nginx.template
# ---------------------

worker_processes ${{ "{{NGINX_WORKER_PROCESSES" }}}}; # can be set by kong.conf
daemon ${{ "{{NGINX_DAEMON" }}}};                     # can be set by kong.conf

pid pids/nginx.pid;                      # this setting is mandatory
error_log logs/error.log ${{ "{{LOG_LEVEL" }}}}; # can be set by kong.conf
events {}

http {
  # here, we inline the contents of nginx_kong.lua
  charset UTF-8;

  # any contents until Kong's Proxy server block
  ...

  # Kong's Proxy server block
  server {
    server_name kong;

    # any contents until the location / block
    ...

    # here, we declare our custom location serving our website
    # (or API portal) which we can optimize for serving static assets
    location / {
      root /var/www/example.net;
      index index.htm index.html;
      ...
    }

    # Kong's Proxy location / has been changed to /api/v1
    location /api/v1 {
      set $upstream_host nil;
      set $upstream_scheme nil;
      set $upstream_uri nil;

      # Any remaining configuration for the Proxy location
      ...
    }
  }

  # Kong's Admin server block goes below
  # ...
}
```

## Properties reference
]]


data.footer = [[


[Penlight]: http://stevedonovan.github.io/Penlight/api/index.html
[pl.template]: http://stevedonovan.github.io/Penlight/api/libraries/pl.template.html
]]

return data
