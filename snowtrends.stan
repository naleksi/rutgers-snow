data {
  int<lower=1> T;  
  real y[T];
  int<lower=0> month[T];
}
parameters {
  real mum[12]; real trend[12]; real trend2[12];
  real<lower=0> trend_sigma; real trend_mean; real trend_amps; real trend_ampc;
  real<lower=0> trend2_sigma; real trend2_mean; real trend2_amps; real trend2_ampc;
  real theta[12]; 
  real<lower=0> sigma[12];
}
transformed parameters {
  vector[T] nu;
  vector[T] err;
  real st;
  for (t in 1:T) {
    st <- (t-1)/(0.0+T);
    nu[t] <- mum[month[t]] + st*trend[month[t]] + (st-.5)*(st-.5)*trend2[month[t]];
    for (lag in 1:12) { if (t>lag) nu[t] <- nu[t] + theta[lag] * err[t-lag]; }
    err[t] <- y[t] - nu[t];  
  }
}
model {
  real pi;
  pi <- 3.141592654;
  for (t in 1:12) { 
    trend2[t] ~ cauchy(trend2_mean + trend2_amps*sin(2*pi*t/12)+trend2_ampc*cos(2*pi*t/12), trend2_sigma);
    trend[t] ~ cauchy(trend_mean + trend_amps*sin(2*pi*t/12)+trend_ampc*cos(2*pi*t/12), trend_sigma); }
  theta ~ normal(0,2); 
  sigma ~ cauchy(0,5);

  for(t in 1:T) err[t] ~ student_t(4, 0, sigma[month[t]]);
}