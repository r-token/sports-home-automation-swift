# Sports Home Automation with Swift Cloud

Backend serverless IaC on AWS to remotely control my Philips Hue bulbs whenever my favorite sports teams score or win. Written in Swift and deployed via [Swift Cloud](https://github.com/swift-cloud/swift-cloud).

Read the blog post about it [here](https://www.ryantoken.com/blog/serverless-swift).

## Commands

* **Deploy**: `swift run Infra deploy --stage prod`
* **Remove**: `swift run Infra remove --stage prod`
* **Preview**: `swift run Infra preview --stage prod`
* **Outputs**: `swift run Infra outputs --stage prod`
* **Cancel**: `swift run Infra cancel --stage prod`

## Infrastructure

It currently consists of six primary pieces of infrastructure, all defined within `Infra/Project.swift`:
1. A cron job managed by EventBridge that triggers my scheduler function
2. A scheduler Lambda function that fires off SQS events every 10 seconds
3. An SQS queue to hold those events
4. A poller Lambda function triggered by SQS that polls the [ncaa-api](https://github.com/henrygd/ncaa-api) for Tulsa football, men’s basketball, and women’s basketball scores, and the [public-espn-api](https://github.com/pseudo-r/Public-ESPN-API) for Eagles scores. It writes those results to DynamoDB
5. A DynamoDB table that keeps track of the games found in the previous step
6. A processor Lambda function triggered by DynamoDB Streams that checks the scores for those teams I care about, and if they scored (football only) or won, make my Philips Hue lights go nuts in that team’s colors

It also consists of two other pieces of infrastructure used to refresh my Hue API tokens every 3 days:
1. A cron job managed by EventBridge that triggers my token refresher function
2. A token refresher Lambda function that refreshes my Hue API tokens
