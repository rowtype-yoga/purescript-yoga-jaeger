const { initTracer: jaegerInitTracer } = require('jaeger-client');

// Initialize tracer
export const initTracerImpl = (config) => {
  const tracerConfig = {
    serviceName: config.serviceName || 'unknown-service',
    sampler: config.sampler || {
      type: 'const',
      param: 1,
    },
    reporter: config.reporter || {
      logSpans: false,
    },
  };

  // Optional configuration
  if (config.traceId128bit !== undefined) {
    tracerConfig.traceId128bit = config.traceId128bit;
  }

  if (config.shareRpcSpan !== undefined) {
    tracerConfig.shareRpcSpan = config.shareRpcSpan;
  }

  const options = {};

  return jaegerInitTracer(tracerConfig, options);
};

// Start span
export const startSpanImpl = (tracer, operationName, options) => {
  const spanOptions = {};

  // Handle childOf
  if (options.childOf) {
    spanOptions.childOf = options.childOf;
  }

  // Handle references - array of { refType, spanContext }
  if (options.references) {
    spanOptions.references = options.references.map(ref => {
      const refType = ref.refType; // SpanReferenceType ADT
      const type = refType.constructor.name === 'ChildOf' ? 'child_of' : 'follows_from';
      return tracer.reference(type, ref.spanContext);
    });
  }

  // Handle tags - Object TagValue
  if (options.tags) {
    const jsTags = {};
    for (const [key, tagValue] of Object.entries(options.tags)) {
      jsTags[key] = tagValueToJS(tagValue);
    }
    spanOptions.tags = jsTags;
  }

  // Handle startTime - Instant is milliseconds since epoch
  if (options.startTime !== undefined) {
    spanOptions.startTime = options.startTime;
  }

  return tracer.startSpan(operationName, spanOptions);
};

// Start span as child
export const startSpanAsChildImpl = (tracer, operationName, parentSpan) => {
  return tracer.startSpan(operationName, {
    childOf: parentSpan.context(),
  });
};

// Get span context
export const getSpanContextImpl = (span) => {
  return span.context();
};

// Convert TagValue ADT to JS value
const tagValueToJS = (tagValue) => {
  // TagValue is an ADT: TagString, TagNumber, or TagBoolean
  if (tagValue.constructor.name === 'TagString') {
    return tagValue.value0;
  } else if (tagValue.constructor.name === 'TagNumber') {
    return tagValue.value0;
  } else if (tagValue.constructor.name === 'TagBoolean') {
    return tagValue.value0;
  }
  return tagValue; // fallback
};

// Set tag
export const setTagImpl = (span, key, tagValue) => {
  span.setTag(key, tagValueToJS(tagValue));
};

// Set multiple tags - convert Object TagValue to Object of JS values
export const setTagsImpl = (span, tags) => {
  const jsTags = {};
  for (const [key, tagValue] of Object.entries(tags)) {
    jsTags[key] = tagValueToJS(tagValue);
  }
  span.addTags(jsTags);
};

// Log
export const logImpl = (span, fields) => {
  span.log(fields);
};

// Log with timestamp - Instant is milliseconds since epoch
export const logWithTimestampImpl = (span, fields, instant) => {
  // Instant is a newtype wrapping milliseconds (Number)
  const timestamp = instant;
  span.log(fields, timestamp);
};

// Set baggage item
export const setBaggageItemImpl = (span, key, value) => {
  span.setBaggageItem(key, value);
};

// Get baggage item
export const getBaggageItemImpl = (span, key) => {
  return span.getBaggageItem(key) || null;
};

// Set operation name
export const setOperationNameImpl = (span, operationName) => {
  span.setOperationName(operationName);
};

// Finish span
export const finishSpanImpl = (span) => {
  span.finish();
};

// Finish span with timestamp - Instant is milliseconds since epoch
export const finishSpanWithTimestampImpl = (span, instant) => {
  const timestamp = instant;
  span.finish(timestamp);
};

// Close tracer
export const closeTracerImpl = (tracer) => {
  return new Promise((resolve, reject) => {
    tracer.close((err) => {
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    });
  });
};

// Inject span context into carrier - returns Object String
export const injectImpl = (tracer, spanContext, format) => {
  const carrier = {};
  tracer.inject(spanContext, format, carrier);
  return carrier;
};

// Extract span context from carrier - takes Object String
export const extractImpl = (tracer, format, carrier) => {
  return tracer.extract(format, carrier) || null;
};
