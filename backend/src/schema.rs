pub mod discuz;
pub mod primary;

use discuz::discuz::common_member;
pub use primary::{
    attachments, clients, group_membership, groups, message_reactions, messages,
    push_subscriptions, sql_types,
};

diesel::allow_tables_to_appear_in_same_query!(group_membership, common_member);
diesel::allow_tables_to_appear_in_same_query!(messages, common_member);
