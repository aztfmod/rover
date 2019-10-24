FROM caf_rover_base

RUN git clone https://github.com/aztfmod/landingzones.git /tf/landingzones
RUN git clone https://github.com/aztfmod/level0.git /tf/level0

ENTRYPOINT [ "./launchpad.sh" ]