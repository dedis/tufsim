#!/usr/bin/env python
# Plots the graph of one of the test-runs
# It takes the CSV-file as argument and shows the plot
# of the times used for each round

import os

os.environ["LC_ALL"] = "en_US.UTF-8"
os.environ["LANG"] = "en_US.UTF-8"

import sys

sys.path.insert(1, '..')
from mplot import MPlot
from stats import CSVStats
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches


def plotData(data, name,
             xlabel="Time since last update", ylabel="Bandwidth",
             xticks=[], loglog=[0, 0], xname="time",
             legend_pos="lower right",
             yminu=0, ymaxu=0,
             xminu=0, xmaxu=0,
             title="", read_plots=True):
    mplot.plotPrepareLogLog(loglog[0], loglog[1])
    if read_plots:
        plots = read_csvs_xname(xname, *data[0])
    else:
        plots = data[0]

    ranges = []
    data_label = []
    plot_show(name)

    for index, label in enumerate(data[1]):
        data_label.append([plots[index], label])
        ranges.append(
            mplot.plotMMA(plots[index], 'cumul_bandwidth', colors[index][0], 4,
                          dict(label=label, linestyle='-', marker='o',
                               color=colors[index][1], zorder=5)))

    # Make horizontal lines and add arrows for JVSS
    xmin, xmax, ymin, ymax = CSVStats.get_min_max(*ranges)
    if yminu != 0:
        ymin = yminu
    if ymaxu != 0:
        ymax = ymaxu
    if xminu != 0:
        xmin = xminu
    if xmaxu != 0:
        xmax = xmaxu
    plt.ylim(ymin, ymax)
    plt.xlim(xmin, xmax)
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)

    plt.legend(loc=legend_pos)
    plt.axes().xaxis.grid(color='gray', linestyle='dashed', zorder=0)
    if len(xticks) > 0:
        ax = plt.axes()
        ax.set_xticks(xticks)
    if title != "":
        plt.title(title)
    mplot.plotEnd()
    return data_label


# Pl
def plotCumulative():
    plotData([['skipchain_0'],
              ['1']], 'comparison_roundtime')
    mplot.plotEnd()


# Plots a Cothority and a JVSS run with regard to their averages. Supposes that
# the last two values from JVSS are off-grid and writes them with arrows7
# directly on the plot
def plotSysUser():
    mplot.plotPrepareLogLog()
    plots = read_csvs('jvss', 'naive_cosi', 'sysusr_ntree', 'sysusr_cosi')
    plot_show('comparison_sysusr')

    if False:
        for index in range(1, len(plots[3].x)):
            for p in range(0, len(plots)):
                if index < len(plots[p].x):
                    plots[p].delete_index(index)

    ymin = 0.05
    bars = []
    deltax = -1.5
    for index, label in enumerate(['JVSS', 'Naive', 'NTree', 'CoSi']):
        bars.append(mplot.plotStackedBarsHatched(plots[index], "round_system",
                                                 "round_user", label,
                                                 colors[index][0],
                                                 ymin, delta_x=deltax + index)[
                        0])

    ymax = 32
    xmax = 50000
    plt.ylim(ymin, ymax)
    plt.xlim(1, xmax)

    usert = mpatches.Patch(color='white', ec='black', label='User',
                           hatch='//')
    syst = mpatches.Patch(color='white', ec='black', label='System')

    plt.legend(handles=[bars[0], bars[1], bars[2], bars[3], usert, syst],
               loc=u'upper left')
    plt.ylabel("Average CPU seconds per round")
    ax = plt.axes()
    ax.set_xticks([2,8,32,128,512,2048,8192, 32768])
    mplot.plotEnd()


# Colors for the Plots
colors = [['lightgreen', 'green'],
          ['lightblue', 'blue'],
          ['yellow', 'brown'],
          ['pink', 'red'],
          ['pink', 'red']]
mplot = MPlot()


def plot_show(file):
    if write_file:
        mplot.pngname = file + '.' + file_extension


def read_csvs_xname(xname, *values):
    stats = []
    for a in values:
        file = a + '.csv'
        stats.append(CSVStats(file, xname))
    return stats


def read_csvs(*values):
    return read_csvs_xname("hosts", *values)


# Write to file
write_file = True
# What file extension - .png, .eps
file_extension = 'png'
file_extension = 'eps'
# Show figure
mplot.show_fig = False
mplot.show_fig = True

# Call all plot-functions
plotCumulative()