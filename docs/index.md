# What is `raya`?

`raya` is the infrastructure powering my little “cloud labs.” It is a k3s
cluster hosted by Hetzner (`hel1` 🇫🇮). My goal with Hetzner is to explore
and experiment with how software is being run in 2026.

I have three rules with this project:

1. Nothing is deployed manually. `raya`’s [Git repository][repo] is the single
   source of truth about what runs on my cluster.
2. Everything is public. The GitHub repository is public, its CI logs are
   accessible. Feel free to have a look if you are curious.
3. This website remains up-to-date and provides a good overview about the hows
   and the whys.

[repo]: https://github.com/lthms/raya

!!! important "Voluntary AI Disclosure"

    I have used a coding assistant to build `raya`. Most of the code and
    configuration making up `raya` has been drafted by a LLM, then reviewed,
    refined and edited by myself to various degree.
    
    On the contrary, this website has been almost entirely authored by myself. I’m
    using LLMs as a conventient editor and a reviewer helping me to find gaps and
    inconsistencies, but as `raya` is first and foremost a learning journey, it
    wouldn’t make sense to me to delegate this to a machine.
