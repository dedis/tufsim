#!/usr/bin/env python
# Plots the graph of one of the test-runs
# It takes the CSV-file as argument and shows the plot
# of the times used for each round

import os

os.environ["LC_ALL"] = "en_US.UTF-8"
os.environ["LANG"] = "en_US.UTF-8"

import sys

sys.path.insert(1, '.')
from mplot import MPlot
from stats import CSVStats
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches


def plotData(data, name,
             xlabel="Time since last update", ylabel="Bandwidth",
             xticks=[], loglog=[0, 0], xname="time",
             legend_pos="lower right",
             yname="bandwidth",
             yminu=0, ymaxu=0,
             xminu=0, xmaxu=0,
             title="", read_plots=True,
             restart_x=False):
    mplot.plotPrepareLogLog(loglog[0], loglog[1])
    if read_plots:
        plots = read_csvs_xname(xname, *data[0])
    else:
        plots = data[0]

    ranges = []
    data_label = []
    plot_show(name)
    subx = 0
    if restart_x:
        subx = plots[0].columns[xname][0]

    for index, label in enumerate(data[1]):
        data_label.append([plots[index], label])
        # plots[index].print_short()
        if restart_x:
            print subx
            plots[index].column_add(xname, -subx)
            plots[index].get_values("time")

        ranges.append(
            mplot.plotMMA(plots[index], yname, colors[index][0], 4,
                          dict(label=label, linestyle='-', marker='.',
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


sc_plots = ['cumul_tuf', 'cumul_sc_2_0',
            'cumul_sc_2_5',
            'cumul_sc_5_5',
            'cumul_sc_7_5',
            'cumul_sc_11_5']
sc_scatter = ['scatter_tuf', 'scatter_2_0',
            'scatter_2_5',
            'scatter_5_5',
            'scatter_7_5',
            'scatter_11_5']
sc_titles = ['TUF', 'SkipChain${_2}{^0}$',
             'SkipChain${_2}{^5}$',
             'SkipChain${_5}{^5}$',
             'SkipChain${_7}{^5}$',
             'SkipChain$11{^5}$']


# Plot the total bandwidth of all users over the given time
def plotCumulative():
    plotData([sc_plots, sc_titles],
             'cumulative_abs',
             restart_x=True, legend_pos="upper left")

def plotCumulDiff():
    mplot.plotPrepareLogLog(0, 0)
    plot_show('cumulative_diff')
    plt.ylabel('Bandwidth [bytes]')
    plt.xlabel('Time since start [s]')
    data = read_csvs_xname("time", *sc_plots)
    styles = ["-"] * 3 + [":"] * 1 + ["--"] * 1 + ["-."] * 2
    subx = data[0].x[0]
    for index, label in enumerate(sc_titles):
        if index == 0:
            continue
        data[index].columns_sub(data[0], "bandwidth", "diff_bandwidth")
        data[index].column_add("time", -subx)
        data[index].get_values("time")
        plt.plot(data[index].x, data[index].columns["diff_bandwidth"],
                      label=label, color=colors[index][1], linestyle=styles[index])
    plt.legend(loc="upper left")
    mplot.plotEnd()

# Plots a scatterplot of all users
def plotScatter():
    mplot.plotPrepareLogLog(0, 0)
    plot_show('scatter')
    plt.ylabel('Bandwidth [bytes]')
    plt.xlabel('Time since start [s]')
    data = read_csvs_xname("time", *sc_scatter)
    styles = ["^"] * 4 + ["s"] * 4
    ranges = []
    for index, label in enumerate(sc_titles):
        if index == 0:
            continue
        plot = data[index]
        y = plot.get_values("bandwidth")
        ranges.append(y)
        plt.scatter(plot.x, y.y, label=label,
                    color=colors[index][1], marker=styles[index])
    plt.legend(loc="upper left")
    xmin, xmax, ymin, ymax = CSVStats.get_min_max(*ranges)
    plt.xlim(0, xmax)
    plt.ylim(0, ymax)
    mplot.plotEnd()


# Colors for the Plots
colors = [['lightgreen', 'green'],
          ['lightblue', 'blue'],
          ['yellow', 'brown'],
          ['pink', 'red'],
          ['lightgreen', 'green'],
          ['lightblue', 'blue'],
          ['yellow', 'brown'],
          ['pink', 'red'],
          ['lightgreen', 'green'],
          ['lightblue', 'blue'],
          ['yellow', 'brown'],
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
# file_extension = 'eps'
# Show figure
mplot.show_fig = False
# mplot.show_fig = True

# Call all plot-functions
plotCumulative()
plotCumulDiff()
plotScatter()