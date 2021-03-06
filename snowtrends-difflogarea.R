library(plyr)
library(reshape2)
library(ggplot2)
library(rstan)

source("working_dir.R")

snow <- read.table("snow.txt")
names(snow) <- c("year", "month", "area")
# Simple difference of areas between months
snow$diff <- snow$area - c(NA, head(snow$area, -1))
# Difference of area in Proportion to starting point
snow$diffprop <- (snow$area - c(NA, head(snow$area, -1))) / c(NA, head(snow$area, -1))
# Difference of logarithm of area
snow$difflog <- log(snow$area) - c(NA, log(head(snow$area, -1)))

snow2 <- snow
snow2$years <- cut(snow2$year, breaks=seq(1966, 2015, 8))
snow2_summary <- ddply(snow2, .(years, month), summarize, diffm=mean(diff, na.rm=T), diffpropm=mean(diffprop, na.rm=T), difflogm=mean(difflog, na.rm=T))

# every year as a line
ggplot() + geom_line(data=snow2, aes(x=month, y=difflog, color=as.factor(year))) + scale_x_discrete(breaks=c(1:12))
# group years (=reduce lines and have averages to smoothen to make the visual comparison easier)
ggplot() + geom_line(data=snow2_summary, aes(x=month, y=difflogm, color=as.factor(years))) + scale_x_discrete(breaks=c(1:12)) + scale_color_brewer(palette=1)


# plot the difference of area (snowing or melting) for every month, over the year range
ggplot() + geom_line(data=snow2, aes(x=year, y=diff)) + facet_grid(~month) + scale_color_brewer(palette=1) 
ggplot() + geom_line(data=snow2, aes(x=year, y=diffprop)) + facet_grid(~month) + scale_color_brewer(palette=1)
ggplot() + geom_line(data=snow2, aes(x=year, y=difflog)) + facet_grid(~month) + scale_color_brewer(palette=1)

ggplot() + geom_line(data=snow2_summary, aes(x=as.numeric(as.factor(years)), y=diffm)) + facet_grid(~month) + scale_color_brewer(palette=1)
ggplot() + geom_line(data=snow2_summary, aes(x=as.numeric(as.factor(years)), y=diffpropm)) + facet_grid(~month) + scale_color_brewer(palette=1)
ggplot() + geom_line(data=snow2_summary, aes(x=as.numeric(as.factor(years)), y=difflogm)) + facet_grid(~month) + scale_color_brewer(palette=1)


plot(snow, pch=".")

ggplot(snow, aes(x=year, y=area, color=as.factor(month))) + geom_line() + geom_smooth() 
ggplot(snow, aes(x=year, y=area, color=as.factor(month))) + geom_line() + 
  geom_smooth(method="lm") + facet_wrap(~ month, scales="free_y")

month.plot <- function (fit, par) {
  tquant <- as.data.frame(t(apply(as.data.frame(fit, par), 2, 
                                  function (x) quantile(x, c(0.05, 0.25, 0.5, 0.75, 0.95)))))
  names(tquant) <- c("llow", "low", par, "high", "hhigh")
  tquant$month <- as.factor(1:12)
  ggplot(tquant, aes_string(x="month", y=par)) + 
    geom_pointrange(aes(ymin=llow, ymax=hhigh)) +
    geom_pointrange(aes(ymin=low, ymax=high), size=1) + theme_bw()
}

m <- stan_model("snowtrends.stan")
sdat <- list(T = nrow(snow), y = sqrt(snow$area/mean(snow$area)), month=as.integer(snow$month))
fit <- sampling(m, data = sdat, pars=c("err", "mum", "trend", "trend2", "sigma", "theta"), 
                iter = 5000, chains = 1, thin=1, init=0, nondiag_mass=T)
plot(fit)

snow$err <- get_posterior_mean(fit, pars="err")[,1]
ggplot(snow, aes(x=year+(month-1)/12, y=err)) + geom_line() + geom_smooth()
hist(snow$err, n=100)
acf(ts(snow$err))

pdf(file="trendplots_logdiffarea.pdf")
month.plot(fit, "mum") + ylab("sqrt area") + ggtitle("Monthly sqrt area (standardized)")
month.plot(fit, "trend") + geom_hline(yintercept=0, color="red") + ggtitle("Sqrt area linear trends") + ylab("coef")
month.plot(fit, "trend2") + geom_hline(yintercept=0, color="red") + ggtitle("Trends: quadratic coeffs") + ylab("coef")
month.plot(fit, "sigma") + ggtitle("Sigma of t4(0, sigma) monthly residual")
month.plot(fit, "theta") + geom_hline(yintercept=0, color="red") + ggtitle("Modelled residual autocorrelation")
ggplot(snow, aes(x=year, y=err)) + 
  geom_point()  + facet_wrap(~ month, scales="free_y") + geom_hline(yintercept=0, color="red") + 
  ggtitle("Monthly residuals")
dev.off()
