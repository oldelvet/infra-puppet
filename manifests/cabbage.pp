#
#   Root manifest to be run on cabbage
#

node /^cabbage$/ {
    $sudo_role = "standard"

    include users-core
    include sudo

    include ntpdate
}