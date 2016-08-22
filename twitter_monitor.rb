require "net/https"
require 'tweetstream'
require 'yaml'

class TwitterMonitor
  def initialize
    config = YAML.load_file('./config.yml')
    @name = config["screen_name"]
    @token = config["token"]
    @pushover = config["pushover"]

    credentials = {
      consumer_key: @token["consumer_key"],
      consumer_secret: @token["consumer_secret"],
      oauth_token: @token["oauth_token"],
      oauth_token_secret: @token["oauth_token_secret"]
    }
    @client = TweetStream::Client.new(credentials)
  end

  def notify(params = {})
    url = URI.parse("https://api.pushover.net/1/messages.json")
    req = Net::HTTP::Post.new(url.path)
    req.set_form_data({
                        :token => @pushover["token"],
                        :user => @pushover["user"],
                        :message => params[:description],
                        :title => params[:title],
                        :url => params[:link]
                      })
    res = Net::HTTP.new(url.host, url.port)
    res.use_ssl = true
    res.verify_mode = OpenSSL::SSL::VERIFY_PEER
    res.start {|http| http.request(req) }
  end

  def userstream
    @client.on_timeline_status do |status|
      # Reply
      if status.in_reply_to_screen_name == @name
        title = 'Mentioned by @' + status.user.screen_name
        desc = status.text
        link = status.uri
        params = {
          :title => title,
          :description => desc,
          :link => link
        }
        notify(params)
      end
      # Retweet
      if status.retweet? && status.retweeted_status.user.screen_name == @name
        title = 'Retweeted by @' + status.user.screen_name
        desc = status.retweeted_status.text
        link = status.retweeted_status.uri
        params = {
          :application => @application,
          :title => title,
          :description => desc,
          :link => link
        }
        notify(params)
      end
    end

    @client.on_direct_message do |direct_message|
      if direct_message.recipient.screen_name == @name
        title = "DM from @" + direct_message.sender.screen_name
        desc = direct_message.text
        link = 'https://twitter.com/'
        params = {
          :title => title,
          :description => desc,
          :link => link
        }
        notify(params)
      end
    end

    @client.on_event(:favorite) do |event|
      title = 'Favorited by @' + event[:source][:screen_name]
      desc = event[:target_object][:text]
      link = 'https://twitter.com/' + event[:target_object][:user][:screen_name] + '/status/' + event[:target_object][:id_str]
      params = {
        :title => title,
        :description => desc,
        :link => link
      }
      notify(params)
    end

    @client.on_event(:unfavorite) do |event|
      title = 'Unfavorited by @' + event[:source][:screen_name]
      desc = event[:target_object][:text]
      link = 'https://twitter.com/' + event[:target_object][:user][:screen_name] + '/status/' + event[:target_object][:id_str]
      params = {
        :title => title,
        :description => desc,
        :link => link
      }
      notify(params)
    end

    @client.on_event(:follow) do |event|
      if event[:target][:screen_name] == @name
        title = 'Follewed'
        desc = 'You have been followed by @' + event[:source][:screen_name]
        link = 'https://twitter.com/' + event[:source][:screen_name]
        params = {
          :title => title,
          :description => desc,
          :link => link
        }
        notify(params)
      end
    end

    @client.on_event(:unfollow) do |event|
      if event[:target][:screen_name] == @name
        title = 'Unfollewed'
        desc =  '@' + event[:source][:screen_name] + 'unfollowed you...'
        link =  'https://twitter.com/' + event[:source][:screen_name]
        params = {
          :title => title,
          :description => desc,
          :link => link
        }
        notify(params)
      end
    end

    @client.on_event(:list_member_added) do |event|
      if event[:source][:screen_name] != @name
        title = 'List membership'
        desc = 'You have been added into: ' + event[:target_object][:full_name]
        link = 'https://twitter.com' + event[:target_object][:uri]
        params = {
          :title => title,
          :description => desc,
          :link => link
        }
        notify(params)
      end
    end

    @client.on_event(:list_member_removed) do |event|
      if event[:source][:screen_name] != @name
        title = 'List membership'
        desc = 'You have been removed from: ' + event[:target_object][:full_name]
        link = 'https://twitter.com' + event[:target_object][:uri]
        params = {
          :title => title,
          :description => desc,
          :link => link
        }
        notify(params)
      end
    end

    @client.on_event(:quoted_tweet) do |event|
      if event[:target][:screen_name] == @name
        title = 'Quoted tweet by @' + event[:source][:screen_name]
        desc = event[:target_object][:text]
        link = 'https://twitter.com/' + event[:source][:screen_name] + '/status/' + event[:source][:id_str]
        params = {
          :title => title,
          :description => desc,
          :link => link
        }
        notify(params)
      end
    end

    @client.userstream
  end
end

monitor = TwitterMonitor.new
monitor.userstream
