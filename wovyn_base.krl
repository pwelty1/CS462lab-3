ruleset wovyn_base {
    meta {
        use module com.twilio alias twilio
        with
          account_sid = meta:rulesetConfig{"account_sid"}
          authtoken = meta:rulesetConfig{"authtoken"}
       shares lastResponse, lastTemp, lastMessage
    }
    global {
      lastResponse = function() {
        {}.put(ent:lastTimestamp,ent:lastResponse)
      }
      lastTemp = function() {
        {}.put(ent:high_temp)
      }
      lastMessage = function() {
        {}.put(ent:lastMessage)
      }
      temperature_threshold = 70
      phone_number = "+13853332010"
    }
  
    rule process_tempature {
      select when wovyn heartbeat
      if event:attrs >< "genericThing" then
        send_directive(event:attrs.klog("attrs"))
        fired {
          ent:lastResponse := event:attrs
          ent:lastTimestamp := time:now()
          raise wovyn event "new_temperature_reading" 
            attributes 
            { "temperature": event:attrs{"genericThing"}{"data"}{"temperature"}[0], "Timestamp": time:now()}
        }
    }
    rule find_high_temps {
      select when wovyn new_temperature_reading
      send_directive(event:attrs.klog("attrs"))
      fired{
        ent:high_temp := event:attrs{"temperature"}
        raise wovyn event "threshold_violation" 
            attributes event:attrs 
            if event:attrs{"temperature"}{"temperatureF"} > temperature_threshold
      }
    }
    rule threshold_notification {
      select when wovyn threshold_violation
      pre{
        messageContent = "Its too hot in there, It's " 
        + event:attrs{"temperature"}{"temperatureF"} + "!"
      }
      twilio:sendMessage(phone_number,messageContent) setting(response)
      fired {
        ent:lastMessage := response
        raise sms event "sent" attributes event:attrs
      }
    }
  } 