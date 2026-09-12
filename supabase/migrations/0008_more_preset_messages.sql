alter table group_messages drop constraint if exists group_messages_preset_key_check;
alter table group_messages add constraint group_messages_preset_key_check
  check (preset_key in (
    'lets_go', 'im_here', 'running_late', 'not_coming', 'on_my_way',
    'here_now', 'almost_there', 'wait_for_me', 'go_ahead', 'all_good',
    'stay_safe', 'be_careful', 'thanks', 'see_you_tomorrow', 'bye'
  ));
