import { createAction } from '@reduxjs/toolkit';
import type { MessageResponse } from '@/api/messages';

export type MessageEventOrigin = 'ws' | 'optimistic' | 'api_confirm' | 'sync';
export type MessageEventScope = 'main' | 'thread';

export interface MessageAddedPayload {
  chatId: string;
  storeChatId: string;
  message: MessageResponse;
  origin: MessageEventOrigin;
  scope: MessageEventScope;
}

export interface MessageConfirmedPayload {
  chatId: string;
  storeChatId: string;
  clientGeneratedId: string;
  message: MessageResponse;
  origin: Exclude<MessageEventOrigin, 'optimistic'>;
  scope: MessageEventScope;
}

export interface MessagePatchedPayload {
  chatId: string;
  messageId: string;
  message: MessageResponse;
}

export const messageAdded = createAction<MessageAddedPayload>('messages/messageAdded');
export const messageConfirmed = createAction<MessageConfirmedPayload>('messages/messageConfirmed');
export const messagePatched = createAction<MessagePatchedPayload>('messages/messagePatched');
