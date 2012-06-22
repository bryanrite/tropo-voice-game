# Tropo Voice Enabled Game

A simple, proof of concept, voice enabled game utilizing Tropo's WebAPI.

## Overview

The game is simple Tic Tac Toe.  The actual game logic is very basic, but shows how to integrate voice commands using Tropo's WebAPI to interact with a webpage.

The application starts up by asking for your phone number.  It will then redirect you to your tic tac toe board and issue an outbound call via the WebAPI to start a new game.  You take turns with the computer, saying or entering the key of the square you want to choose.

**Please Note:** This application uses jQuery to poll for new actions to keep the application self-contained and simple. In reality, you would want to utilize a queing mechanism and potentially a sub/pub interface like BOSH or WebSockets to keep the UI updated properly.  This would alleviate synchronization issues and inefficient resource utilization you might find in this proof of concept.

## Setup

### Sinatra App

Run `bundle install` to get all the dependencies.

Copy `config/config.sample.yml` to `config/config.yml`.  You will get your Tropo token in a minute.

You should be able to start the Sinatra app now by running `ruby application.rb`

Going to `http://localhost:4567` should display the game's start page.  It will not run yet as you still need a valid Tropo token first.

Make sure that this application is available to the internet and not firewalled as your Tropo application will need to send data to it.  Make note of its URL.

### Tropo App

A WebAPI Tropo application has to be created.  Log into Tropo, create a WebAPI application, and set the callback URL to your Sinatra application: `http://your-sinatra-app.com/start_game.json`

Your newly created Tropo Application will have an associated **Outbound Token**, listed underneath the application's phone numbers.  Copy and paste this outbound token to the Sinatra application's config file.

_Note: The token you see on your application page is not the entire token.  Make sure you click the token you see and copy and paste the entire token from the modal that will pop up._

## Usage

Return to your Sinatra App's start page.  Simply enter your phone number and click the start game button.  You're now playing tic tac toe over the phone!
