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
             restart_x=False, ymul=1.0, xmul=1.0,
             markers=".", mevery=1):
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
            plots[index].column_add(xname, -subx)
            plots[index].get_values("time")

        plots[index].column_mul(yname, ymul)
        plots[index].column_mul(xname, xmul)
        m = markers[index % len(markers)]
        ranges.append(
            mplot.plotMMA(plots[index], yname, colors[index], 4,
                          dict(label=label, linestyle='-', marker=m, markevery=mevery,
                               color=colors[index], zorder=10 - index)))

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


sc_plots = []
sc_random = []
sc_scatter = []
for base in ['tuf', 'diplomat', 'height0']:
    sc_plots.append('cumul_' + base)
    sc_random.append('random_' + base)
    sc_scatter.append('scatter_' + base)

sc_titles = ['Linear update', 'Diplomat', 'SkipChain $\mathcal{S}_{1}^{1}$']
#sc_rand_titles = sc_titles
sc_rand_titles = ['Linear update', 'Diplomat', 'SkipChain $\mathcal{S}_{1}^{1}$']

for base in ['2_5', '5_5', '11_5', '17_5']:
    sc_plots.append('cumul_sc_' + base)
    sc_scatter.append('scatter_sc_' + base)
    b, h = base.split("_")
    sc_random.append('random_sc_' + str(round(1.0 / float(b), 3)) + '_' + h)
    sc_titles.append('SkipChain $\mathcal{S}_{' + b + '}^{' + h + '}$')
    sc_rand_titles.append(r'SkipChain $\mathcal{S}_{1/' + b + '}^{' + h + '}$')

#print sc_plots, sc_scatter, sc_random


# Plot the total bandwidth of all users over the given time
def plotCumulative():
    plotData([sc_plots[0:3], sc_titles[0:3]],
             'cumulative_abs', loglog=[0, 10], yminu=1e2, ymaxu=1e6,
             restart_x=True, legend_pos="upper left",
             ymul=1e-6, xmul=1.0 / 86400,
             ylabel="Total Bandwidth (MBytes)",
             xlabel="Time since start (d)",
             markers="x+........", mevery=markevery_plot)


def plotCumulativeRandom():
    plotData([sc_random[0:3], sc_rand_titles[0:3]],
             'cumulative_random_abs', loglog=[0, 10], yminu=1e2, ymaxu=1e6,
             restart_x=True, legend_pos="upper left",
             ymul=1e-6, xmul=1.0 / 86400,
             ylabel="Total Bandwidth (MBytes)",
             xlabel="Time since start (d)",
             markers="x+........", mevery=markevery_plot)


def plotCumulDiff(plots=sc_plots, titles=sc_titles, name='cumulative_diff'):
    mplot.plotPrepareLogLog(0, 10)
    plot_show(name)
    plt.ylabel('SkipChain Bandwidth (MBytes)')
    plt.xlabel('Time since start (d)')
    data = read_csvs_xname("time", *plots)
    styles = ["-"] * 4 + [":"] * 2 + ["--"] * 1 + ["-."] * 1
    subx = data[0].x[0]
    xmax = 0
    ymax = 0
    for index, label in enumerate(titles):
        if index <= 1:
            continue
        yname = "diff_bandwidth"
        data[index].columns_sub(data[1], "bandwidth", yname)
        data[index].column_add("time", -subx)
        data[index].column_mul("time", 1.0 / 86400)
        data[index].column_mul(yname, 1e-6)
        data[index].get_values("time")
        xmax = max(xmax, max(data[index].x))
        ymax = max(ymax, max(data[index].columns[yname]))
        plt.plot(data[index].x, data[index].columns[yname], markevery=markevery_plot,
                 label=label, color=colors[index], linestyle=styles[index])
    plt.legend(loc="upper left")
    plt.xlim(0, xmax)
    plt.ylim(1)
    mplot.plotEnd()


# Plots a scatterplot of all users
def plotScatter(diff=False):
    mplot.plotPrepareLogLog(0, 10)
    if diff:
        plot_show('scatter_diff')
    else:
        plot_show('scatter')

    if diff:
        plt.ylabel('SkipChain Bandwidth (MBytes)')
    else:
        plt.ylabel('Total Bandwidth (MBytes)')

    plt.xlabel('Time since last update (d)')
    data = read_csvs_xname("time", *sc_scatter)
    yname = "bandwidth"
    styles = "x+^^^^o.vo"
    ranges = []
    ymax = 0
    for index, label in enumerate(sc_titles):
        plot = data[index]
        if diff:
            if index <= 1:
                continue
            plot.columns_sub(data[1], yname, yname)
        else:
            if index > 2:
                continue

        plot.column_mul(yname, 1e-6)
        plot.column_mul("time", 1.0 / 86400)
        y = plot.get_values(yname, markevery_scatter)
        ranges.append(y)
        plt.scatter(y.x, y.y, label=label,
                    color=colors[index], marker=styles[index], zorder=-index)
    plt.legend(loc="upper left")
    xmin, xmax, ymin, ymax = CSVStats.get_min_max(*ranges)
    plt.xlim(0, xmax)
    if diff:
      plt.ylim(1e-3, ymax)
    else:
      plt.ylim(1, ymax)
    mplot.plotEnd()


# Colors for the Plots
colorpairs = [['lightgreen', 'green'],
              ['lightblue', 'blue'],
              ['yellow', 'brown'],
              ['pink', 'red'],
              ['green', 'lightgreen'],
              ['blue', 'lightblue'],
              ['brown', 'yellow'],
              ['pink', 'red'],
              ['lightgreen', 'green'],
              ['lightblue', 'blue'],
              ['yellow', 'brown'],
              ['pink', 'red']]
colors = [
    '#000000',
    '#000000',
    '#ff8888',
    '#00cc00',
    '#0000ff',
    '#888800',
    '#ff00ff',
    '#00cccc'
]
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
markevery_plot = 200
markevery_scatter = 20

# Call all plot-functions
plotCumulative()
plotCumulativeRandom()
plotCumulDiff()
plotScatter()
plotScatter(True)
plotCumulDiff(sc_random, sc_rand_titles, 'cumulative_random_diff')
