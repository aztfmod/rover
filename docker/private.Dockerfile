
FROM caf_rover_base

COPY level0 /tf/level0
COPY private/landingzones /tf/landingzones

ENTRYPOINT [ "./launchpad.sh" ]