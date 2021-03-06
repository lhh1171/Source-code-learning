/*
 * Licensed to the Apache Software Foundation (ASF) under one or more contributor license
 * agreements. See the NOTICE file distributed with this work for additional information regarding
 * copyright ownership. The ASF licenses this file to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance with the License. You may obtain a
 * copy of the License at http://www.apache.org/licenses/LICENSE-2.0 Unless required by applicable
 * law or agreed to in writing, software distributed under the License is distributed on an "AS IS"
 * BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License
 * for the specific language governing permissions and limitations under the License.
 */

package org.apache.hadoop.hbase.ipc;

import java.io.IOException;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.hadoop.hbase.classification.InterfaceAudience;
import org.apache.hadoop.hbase.HConstants;
import org.apache.hadoop.hbase.ServerName;
import org.apache.hadoop.hbase.client.HConnection;
import org.apache.hadoop.hbase.protobuf.ProtobufUtil;
import org.apache.hadoop.hbase.protobuf.generated.ClientProtos;
import org.apache.hadoop.hbase.protobuf.generated.ClientProtos.CoprocessorServiceResponse;
import org.apache.hadoop.hbase.util.ByteStringer;


import com.google.protobuf.Descriptors;
import com.google.protobuf.Message;

/**
 * Provides clients with an RPC connection to call coprocessor endpoint
 * {@link com.google.protobuf.Service}s against a given region server. An instance of this class may
 * be obtained by calling {@link org.apache.hadoop.hbase.client.HBaseAdmin#coprocessorService(ServerName)},
 * but should normally only be used in creating a new {@link com.google.protobuf.Service} stub to
 * call the endpoint methods.
 * @see org.apache.hadoop.hbase.client.HBaseAdmin#coprocessorService(ServerName)
 */
@InterfaceAudience.Private
public class RegionServerCoprocessorRpcChannel extends CoprocessorRpcChannel {
  private static Log LOG = LogFactory.getLog(RegionServerCoprocessorRpcChannel.class);
  private final HConnection connection;
  private final ServerName serverName;

  public RegionServerCoprocessorRpcChannel(HConnection conn, ServerName serverName) {
    this.connection = conn;
    this.serverName = serverName;
  }

  @Override
  protected Message callExecService(Descriptors.MethodDescriptor method, Message request,
      Message responsePrototype) throws IOException {
    if (LOG.isTraceEnabled()) {
      LOG.trace("Call: " + method.getName() + ", " + request.toString());
    }

    final ClientProtos.CoprocessorServiceCall call =
        ClientProtos.CoprocessorServiceCall.newBuilder()
            .setRow(ByteStringer.wrap(HConstants.EMPTY_BYTE_ARRAY))
            .setServiceName(method.getService().getFullName()).setMethodName(method.getName())
            .setRequest(request.toByteString()).build();
    CoprocessorServiceResponse result =
        ProtobufUtil.execRegionServerService(connection.getClient(serverName), call);
    Message response = null;
    if (result.getValue().hasValue()) {
      response =
          responsePrototype.newBuilderForType().mergeFrom(result.getValue().getValue()).build();
    } else {
      response = responsePrototype.getDefaultInstanceForType();
    }
    if (LOG.isTraceEnabled()) {
      LOG.trace("Result is value=" + response);
    }
    return response;
  }
}
