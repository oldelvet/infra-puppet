#
#   Run pkg.depotd servers for
#   mirrors.jenkins-ci.org
#

define ips::repository($name,$port) {
    # empty place holder for the repository
    file { "/srv/ips/ips$name":
        ensure => directory,
        mode => 755,
        owner  => "ips";
    }

    # reverse proxy configuration
    file { "/etc/apache2/sites-available/ips$name.conf":
        owner => "ips",
        notify => Exec["reload-apache2"],
        content => template("ips/reverse-proxy.conf.erb");
    }

    # upstart script
    file { "/etc/init/pkg.depotd$name.conf":
        owner => "root",
        group => "root",
        content => template("ips/pkg.depotd.conf.erb"),
        notify => Service["pkg.depotd$name"];
    }

    # SysV init compatibility layer
    file { "/etc/init.d/pkg.depotd$name":
        ensure => "/lib/init/upstart-job",
        notify => Service["pkg.depotd$name"];
    }

    # seed the initial empty repository if there's no data
    exec {  "seed$name":
        command => "tar xvzf ../empty-repo.tgz",
        cwd => "/srv/ips/ips$name",
        unless => "test -f /srv/ips/ips$name/cfg_cache"
    }

    # for some reason, the following doesn't do anything
    service { "pkg.depotd$name":
        ensure => "running",
        status => "status pkg.depotd$name | grep -q 'running'"
    }
}

class ips {
    # this service uses Apache as a frontend
    include apache2
    Class["apache2"] -> Class["ips"]

    package {
        "ips" :
            provider => "dpkg",
            ensure => installed,
            source => "/srv/ips/ips.deb";
    }

    group {
        "ips" :
            ensure  => present;
    }

    # ips repositories run in a separate user
    user {
        "ips" :
            shell   => "/usr/bin/zsh",
            home    => "/srv/ips",
            ensure  => present,
            gid     => "ips",
            require => [
                Package["zsh"]
            ];
    }

    file {
        "/srv/ips/" :
            ensure      => directory,
            owner       => "ips",
            group       => "ips";

        "/srv/ips/.ssh" :
            ensure      => directory,
            owner       => "ips",
            group       => "ips";

        "/srv/ips/empty-repo.tgz" :
            source      => "puppet:///modules/ips/empty-repo.tgz";

        "/srv/ips/ips.deb" :
            source      => "puppet:///modules/ips/ips_2.3.54-0_all.deb";

        "/var/log/apache2/ips.jenkins-ci.org":
            ensure      => directory,
            owner       => "root",
            group       => "root";

        "/etc/apache2/sites-available/ips.jenkins-ci.org":
            ensure      => directory,
            owner       => "root",
            group       => "root",
            source      => "puppet:///modules/ips/ips.jenkins-ci.org";

        "/etc/apache2/sites-enabled/ips.jenkins-ci.org":
            notify      => Exec["reload-apache2"],
            ensure      => "../sites-available/ips.jenkins-ci.org";

        "/var/www/ips.jenkins-ci.org/":
            ensure      => "directory";

        "/var/www/ips.jenkins-ci.org/index.html":
            source      => "puppet:///modules/ips/www/index.html";

        "/var/www/ips.jenkins-ci.org/headshot.png":
            source      => "puppet:///modules/ips/www/headshot.png";
    }


    enable-apache-mod {
        "proxy_http" :
            name => "proxy_http";
    }

    ssh_authorized_key {
        "ips" :
            user        => "ips",
            ensure      => present,
            require     => File["/srv/ips/.ssh"],
            key         => "AAAAB3NzaC1yc2EAAAABIwAAAQEArSave9EBJ2rP3Hm5PFyiOpfGsPhJwjqdyaVEwQruM0Fa8nWstla7cdSTSs/ClHn7I1uUzQvX+/+6m/HTVy/WIr0cIIxLDm8hXVLfCLddtvxnXx47fJY3ongasYJ4TarIGkMMX/Vg1JpP7XIkMczUSNRyeHg/bGfV+YCPFuSW+cj2M5yMOE1KyIVQQL/JZu7lu80Ara5+RWSITObdiHRpnNzvBdIyhkSCrG0N7QStIBnEaLU//K2AB5GbK/65+k7sklutcH18wSGridQCNJm4ODUxov+vVr2OH3oiv7gyHEE9TypRI9vS0HUmsD+moPq3O8y0xyP8xaJWkz2LKe8/5Q==",
            type        => "rsa",
            name        => "kohsuke@unicorn.2010/ips";
    }

    include ips::repositories
    Class["ips"] -> Class["ips::repositories"]
}

class ips::repositories {
    # repository definitions
    ips::repository {
        "main":
            name => "",
            port => 8060;
        "stable":
            name => "-stable",
            port => 8061;
        "rc":
            name => "-rc",
            port => 8062;
        "stable-rc":
            name => "-stable-rc",
            port => 8063;
    }
}
