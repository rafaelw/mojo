// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.domokit.contacts;

import android.content.Context;

import org.chromium.mojo.system.Core;
import org.chromium.mojo.system.MessagePipeHandle;
import org.chromium.mojo.system.MojoException;
import org.chromium.mojom.contacts.Contact;
import org.chromium.mojom.contacts.ContactsService;
import org.chromium.mojom.contacts.ContactsService.GetContactResponse;

/**
 * Android implementation of Senors.
 */
public class ContactsServiceImpl implements ContactsService {
    private Context mContext;

    public ContactsServiceImpl(Context context, Core core, MessagePipeHandle pipe) {
        mContext = context;

        ContactsService.MANAGER.bind(this, pipe);
    }

    @Override
    public void close() {}

    @Override
    public void onConnectionError(MojoException e) {}

    @Override
    public void getContact(GetContactResponse response) {
      Contact contact = new Contact();
      contact.name = "Mr Happy Pants";
      response.call(contact);
    }
}
