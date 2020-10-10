### Load in Data
setwd("C:/Users/patjw/Downloads/Tech Stuff")
df <- read.csv("NBAData.csv")

##Install Packages
install.packages("ggplot2")
install.packages("plotly")
install.packages("ggthemes")
install.packages("corrplot")
install.packages("dplyr")
install.packages("caTools")
install.packages("car")

library(ggplot2)
library(plotly)
library(ggthemes)
library(corrplot)
library(dplyr)
library(caTools)
library(RColorBrewer)
library(car)

###Data Cleaning
sum(is.na(df))
sum(is.null(df))
colnames(df)
str(df)

##Rename Opponent's Reb % 
df <- rename(df, OPP_OREB. = OPP.REB..)
## Check .. Opponent's Off Reb % + Our Def Reb % should sum to 100 (All possible rebounds)
df$DREB. + df$OPP_OREB.

#Remove ID Variable 
df <-subset(df, select = -c(ID))

###Converting Variables to Numeric
## Removing Team and Team_season as they should remain factors
dftrim <- subset(df, select = -c(TEAM, Team_Season))
dftrim <- dftrim %>% mutate_if(is.factor,as.numeric)

#Add back the Team and Team_Season Variables
dftrim$TEAM <- df$TEAM
dftrim$Team_Season <- df$Team_Season

##Check that Variables are as they should be
str(dftrim)
head(dftrim$Team_Season)

## Adjusting FTA.RATE to a % rather than Ratio
mean(dftrim$FTA.RATE)
dftrim$FTA.RATE <- dftrim$FTA.RATE * 100
dftrim$OPP.FTA.RATE <- dftrim$OPP.FTA.RATE * 100
mean(dftrim$OPP.FTA.RATE)

##Correlation between Variables on Wins
CorrelationW <- cor(dftrim$W, select(dftrim, -c(TEAM, Team_Season, Season.End)))
corrplot(CorrelationW, method = "number")
CorrelationW

### Train Test Split 
dftrain <- filter(dftrim, Season.End < 2016 & Season.End != 2012)
dftest <- filter(dftrim, Season.End >= 2016 & Season.End != 2020)

##Means & Standard Deviations
colMeans(dftrain[sapply(dftrain, is.numeric)])
colMeans(dftest[sapply(dftest, is.numeric)])

apply(dftrain, 2, sd)
apply(dftest, 2, sd)


### Regression 4 Factors on Championship Contenders

Reg4Factors <- lm(W ~ EFG. + TOV.
                  + OREB. + FTA.RATE +
                    + OPP.EFG. + OPP.TOV.. + OPP.FTA.RATE + 
                    + OPP_OREB., data = dftrain)
summary(Reg4Factors)

###Predictions on Test Set
WinPredictions4Factors <- predict(Reg4Factors, newdata = dftest)
head(WinPredictions4Factors)

dftest$predictions4Factors <- predict(Reg4Factors, newdata = dftest)
head(dftest$predictions4Factors)
dftest$residuals4Factors <- dftest$W - dftest$predictions4Factors
head(dftest$residuals4Factors)

##Calculating SSE
SSE <- sum((WinPredictions4Factors - dftest$W)^2)
SST <- sum((mean(dftrain$W) - dftest$W)^2)
R2 <- 1 - SSE/SST
R2

##Computing RMSE
RMSE <- sqrt(SSE/nrow(dftest))
RMSE

### Plot Residuals 
bold_axis <- element_text(face = "bold", color = "black", size = 20)
axis_text <- element_text(face = "bold", size = 14)

residualplot4Factors <- ggplot(dftest, aes(x = predictions4Factors, y = residuals4Factors))  + geom_point()
residualplot4Factors + geom_smooth(method = "lm", color = "lightgrey") + geom_text(aes(label=Team_Season, vjust = 0, hjust = .5, color = W)) + scale_color_continuous(low = "royalblue1", high = "red2") + labs(title ="Fitted vs. Residuals", y = "Residuals", x = "Predicted Wins", colour = "Actual Wins") + theme(axis.text = axis_text) + theme(title = bold_axis)                                       

### Improving the Model

###Feature Engineering (on Original Dataset and will split again)
dftrim$X2PA <- dftrim$FGA - dftrim$X3PA
dftrim$X2PM <- dftrim$FGM - dftrim$X3PM
dftrim$X2P. <- dftrim$X2PM / dftrim$X2PA
### FGA by shot as a % of all FGA exists as a variable (will serve as weight)

##Points Per shot = FG% * Points for Make
dftrim$pointsper3pt <- (dftrim$X3P. * 3) / 100
dftrim$pointsper2pt <- (dftrim$X2P. * 2)

## Weighted Points per Shot
dftrim$weightedpointsper2ptA <- (dftrim$X.FGA_2PT/100) * dftrim$pointsper2pt
dftrim$weightedpointsper3ptA <- (dftrim$X.FGA_3PT/100) * dftrim$pointsper3pt

dftrim$pointspershot <- dftrim$weightedpointsper2ptA + dftrim$weightedpointsper3ptA

## Replicating for Opponent - Weighted Average for Opponent

dftrim$OPP_X2PA <- dftrim$OPP_FGA - dftrim$OPP_3PA
dftrim$OPP_X2PM <- dftrim$OPP_FGM - dftrim$OPP_3PM
dftrim$OPP_X2P. <- dftrim$OPP_X2PM / dftrim$OPP_X2PA

## Have to create Weights for Opponent
dftrim$OPP_X.FGA_2PT <- dftrim$OPP_X2PA / dftrim$OPP_FGA
dftrim$OPP_X.FGA_3PT <- dftrim$OPP_3PA / dftrim$OPP_FGA

## Opponent Points Per Shot
dftrim$OPP_pointsper2pt <- (dftrim$OPP_X2P. * 2)
dftrim$OPP_pointsper3pt <- (dftrim$OPP_3P. * 3) / 100

## Weighted Average Points Per Shot for Opponent

dftrim$OPP_weightedpointspershot2pt <- (dftrim$OPP_X.FGA_2PT * dftrim$OPP_pointsper2pt)
dftrim$OPP_weightedpointspershot3pt <- (dftrim$OPP_X.FGA_3PT * dftrim$OPP_pointsper3pt)

dftrim$OPP_pointspershot <- dftrim$OPP_weightedpointspershot2pt + dftrim$OPP_weightedpointspershot3pt

##Resplit the Train Test Data
dftrain <- filter(dftrim, Season.End < 2016 & Season.End != 2012)
dftest <- filter(dftrim, Season.End >= 2016 & Season.End != 2020)

## Custom Regression, Non Standardized With Intercept

Reg4Custom <- lm(W ~ weightedpointsper2ptA + weightedpointsper3ptA + TOV. + OREB. + FTA.RATE + FT.
                 + OPP_weightedpointspershot2pt + OPP_weightedpointspershot3pt + OPP_OREB. + OPP.TOV.. + OPP.FTA.RATE + OPP_FT.,
                 data = dftrain)
summary(Reg4Custom)

##Predictions for Test Set
WinPredictions4Custom <- predict(Reg4Custom, newdata = dftest)
head(WinPredictions4Custom)

dftest$predictions4Custom <- predict(Reg4Custom, newdata = dftest)
head(dftest$predictions4Custom)
dftest$residuals4Custom <- dftest$W - dftest$predictions4Custom
head(dftest$residuals4Custom)


##Calculating SSE
SSE_Custom <- sum((WinPredictions4Custom - dftest$W)^2)
SST_Custom <- sum((mean(dftrain$W) - dftest$W)^2)
R2_Custom <- 1 - SSE_Custom/SST_Custom
R2_Custom

##Computing RMSE
RMSE_Custom <- sqrt(SSE_Custom/nrow(dftest))
RMSE_Custom

### Plot Residuals 

residualplotCustom <- ggplot(dftest, aes(x = predictions4Custom, y = residuals4Custom))  + geom_point()
residualplotCustom + geom_smooth(method = "lm", color = "lightgrey") + geom_text(aes(label=Team_Season, vjust = 0, hjust = .5, color = W)) + scale_color_continuous(low = "royalblue1", high = "red2") + labs(title = "Fitted vs. Residuals - Custom", y = "Residuals", x = "Predicted Wins", colour = "Actual Wins") + theme(axis.text = axis_text) + theme(title = bold_axis)                             

install.packages("car")
library(car)
vif(Reg4Custom)

## Testing for Contenders - Four Factors

### Train Test Split 
dftrain_Contenders <- filter(dftrim, Season.End < 2016 & Season.End != 2012 & W >= 50) 
dftest_Contenders <- filter(dftrim, Season.End >= 2016 & Season.End != 2020 & W >= 50)

##Means & Standard Deviations
colMeans(dftrain_Contenders[sapply(dftrain_Contenders, is.numeric)])
colMeans(dftest_Contenders[sapply(dftest_Contenders, is.numeric)])

apply(dftrain_Contenders, 2, sd)
apply(dftest_Contenders, 2, sd)

## Oliver's Four Factors Test on Contenders

Reg4Factors_Contenders <- lm(W ~ EFG. + TOV.
                             + OREB. + FTA.RATE +
                               + OPP.EFG. + OPP.TOV.. + OPP.FTA.RATE + 
                               + OPP_OREB., data = dftrain_Contenders)
summary(Reg4Factors_Contenders)

###Predictions on Test Set
WinPredictions4Factors_Contenders <- predict(Reg4Factors_Contenders, newdata = dftest_Contenders)
head(WinPredictions4Factors_Contenders)

dftest_Contenders$predictions4Factors <- predict(Reg4Factors_Contenders, newdata = dftest_Contenders)
head(dftest_Contenders$predictions4Factors)
dftest_Contenders$residuals4Factors <- dftest_Contenders$W - dftest_Contenders$predictions4Factors
head(dftest_Contenders$residuals4Factors)


##Calculating SSE
SSE_Contenders <- sum((WinPredictions4Factors_Contenders - dftest_Contenders$W)^2)
SST_Contenders <- sum((mean(dftrain_Contenders$W) - dftest_Contenders$W)^2)
R2_Contenders <- 1 - SSE_Contenders/SST_Contenders
R2_Contenders

##Computing RMSE
RMSE_Contenders <- sqrt(SSE_Contenders/nrow(dftest_Contenders))
RMSE_Contenders

### Plot Residuals 
residualplot4Factors_Contenders <- ggplot(dftest_Contenders, aes(x = predictions4Factors, y = residuals4Factors))  + geom_point()
residualplot4Factors_Contenders + geom_smooth(method = "lm", color = "black") + geom_text(aes(label=Team_Season, vjust = 0, hjust = .5, color = W)) + scale_color_continuous(low = "royalblue1", high = "red2") + labs(title = "Fitted vs. Residuals - Four Factors on Contenders", y = "Residuals", x = "Predicted Wins", colour = "Actual Wins") + theme(axis.text = axis_text) + theme(title = bold_axis) 


head(arrange(dftest_Contenders, residuals4Factors, select(dftest_Contenders, c(Team_Season, residuals4Factors))),5)

## Custom Regression on Contenders

Reg4Custom_Contenders <- lm(W ~ weightedpointsper2ptA + weightedpointsper3ptA + TOV. + OREB. + FTA.RATE + FT.
                            + OPP_weightedpointspershot2pt + OPP_weightedpointspershot3pt + OPP_OREB. + OPP.TOV.. + OPP.FTA.RATE + OPP_FT.,
                            data = dftrain_Contenders)
summary(Reg4Custom_Contenders)

###Predictions on Test Set
WinPredictions4Custom_Contenders <- predict(Reg4Custom_Contenders, newdata = dftest_Contenders)
head(WinPredictions4Custom_Contenders)

dftest_Contenders$predictions4Custom <- predict(Reg4Custom_Contenders, newdata = dftest_Contenders)
head(dftest_Contenders$predictions4Custom)
dftest_Contenders$residuals4Custom <- dftest_Contenders$W - dftest_Contenders$predictions4Custom
head(dftest_Contenders$residuals4Custom)


##Calculating SSE
SSE_Custom_Contenders <- sum((WinPredictions4Custom_Contenders - dftest_Contenders$W)^2)
SST_Custom_Contenders <- sum((mean(dftrain_Contenders$W) - dftest_Contenders$W)^2)
R2_Custom_Contenders <- 1 - SSE_Custom_Contenders/SST_Custom_Contenders
R2_Custom_Contenders

##Computing RMSE
RMSE_Custom_Contenders <- sqrt(SSE_Custom_Contenders/nrow(dftest_Contenders))
RMSE_Custom_Contenders  

### Plot Residuals 
residualplot4Custom_Contenders <- ggplot(dftest_Contenders, aes(x = predictions4Custom, y = residuals4Custom))  + geom_point()
residualplot4Custom_Contenders + geom_smooth(method = "lm", color = "black") + geom_text(aes(label=Team_Season, vjust = 0, hjust = .5, color = W)) + scale_color_continuous(low = "royalblue1", high = "red2") + labs(title = "Fitted vs. Residuals - Custom on Contenders", y = "Residuals", x = "Predicted Wins", colour = "Actual Wins") + theme(axis.text = axis_text) + theme(title = bold_axis)

head(arrange(dftest_Contenders, residuals4Custom, select(dftest_Contenders, c(Team_Season, residuals4Custom))),5)






















