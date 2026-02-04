module Yoga.Jaeger.Jaeger where

import Prelude

import Data.DateTime.Instant (Instant)
import Data.Int (toNumber)
import Data.Maybe (Maybe)
import Data.Newtype (class Newtype)
import Data.Nullable (Nullable, toMaybe, toNullable)
import Data.Time.Duration (Milliseconds)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Uncurried (EffectFn1, EffectFn2, EffectFn3, EffectFn4, runEffectFn1, runEffectFn2, runEffectFn3, runEffectFn4)
import Foreign.Object (Object)
import Foreign.Object as Object
import Prim.Row (class Union)
import Promise (Promise)
import Promise.Aff (toAffE) as Promise
import Type.Row.Homogeneous (class Homogeneous)
import Unsafe.Coerce (unsafeCoerce)

-- Opaque Jaeger types
foreign import data Tracer :: Type
foreign import data Span :: Type
foreign import data SpanContext :: Type

-- Newtypes for type safety

-- Service and operation names
newtype ServiceName = ServiceName String
derive instance Newtype ServiceName _
derive newtype instance Eq ServiceName
derive newtype instance Show ServiceName

newtype OperationName = OperationName String
derive instance Newtype OperationName _
derive newtype instance Eq OperationName
derive newtype instance Show OperationName

-- Agent configuration
newtype AgentHost = AgentHost String
derive instance Newtype AgentHost _
derive newtype instance Eq AgentHost
derive newtype instance Show AgentHost

newtype AgentPort = AgentPort Int
derive instance Newtype AgentPort _
derive newtype instance Eq AgentPort
derive newtype instance Ord AgentPort
derive newtype instance Show AgentPort

-- Collector configuration
newtype CollectorEndpoint = CollectorEndpoint String
derive instance Newtype CollectorEndpoint _
derive newtype instance Eq CollectorEndpoint
derive newtype instance Show CollectorEndpoint

newtype Username = Username String
derive instance Newtype Username _
derive newtype instance Eq Username
derive newtype instance Show Username

newtype Password = Password String
derive instance Newtype Password _
derive newtype instance Eq Password
derive newtype instance Show Password

-- Tag value types (OpenTracing supports string, number, boolean)
data TagValue 
  = TagString String
  | TagNumber Number
  | TagBoolean Boolean

derive instance Eq TagValue
instance Show TagValue where
  show (TagString s) = "TagString " <> show s
  show (TagNumber n) = "TagNumber " <> show n
  show (TagBoolean b) = "TagBoolean " <> show b

-- Sampling types
newtype SamplingRate = SamplingRate Number
derive instance Newtype SamplingRate _
derive newtype instance Eq SamplingRate
derive newtype instance Ord SamplingRate
derive newtype instance Show SamplingRate

newtype SamplerType = SamplerType String
derive instance Newtype SamplerType _
derive newtype instance Eq SamplerType
derive newtype instance Show SamplerType

newtype SamplerHostPort = SamplerHostPort String
derive instance Newtype SamplerHostPort _
derive newtype instance Eq SamplerHostPort
derive newtype instance Show SamplerHostPort

-- Baggage types
newtype BaggageKey = BaggageKey String
derive instance Newtype BaggageKey _
derive newtype instance Eq BaggageKey
derive newtype instance Show BaggageKey

newtype BaggageValue = BaggageValue String
derive instance Newtype BaggageValue _
derive newtype instance Eq BaggageValue
derive newtype instance Show BaggageValue

-- Format types for inject/extract
newtype Format = Format String
derive instance Newtype Format _
derive newtype instance Eq Format
derive newtype instance Show Format

-- Span reference types
data SpanReferenceType = ChildOf | FollowsFrom

derive instance Eq SpanReferenceType
derive instance Ord SpanReferenceType

instance Show SpanReferenceType where
  show ChildOf = "child_of"
  show FollowsFrom = "follows_from"

-- Configuration types

-- Sampler configuration
type SamplerConfig =
  { "type" :: SamplerType
  , param :: SamplingRate
  , hostPort :: SamplerHostPort
  , refreshIntervalMs :: Milliseconds
  }

-- Reporter configuration
type ReporterConfig =
  { logSpans :: Boolean
  , agentHost :: AgentHost
  , agentPort :: AgentPort
  , collectorEndpoint :: CollectorEndpoint
  , username :: Username
  , password :: Password
  , flushIntervalMs :: Milliseconds
  }

-- Tracer configuration
type TracerConfigImpl =
  ( serviceName :: ServiceName
  , sampler :: SamplerConfig
  , reporter :: ReporterConfig
  , traceId128bit :: Boolean
  , shareRpcSpan :: Boolean
  )

-- Initialize tracer
foreign import initTracerImpl :: forall opts. EffectFn1 { | opts } Tracer

initTracer :: forall opts opts_. Union opts opts_ TracerConfigImpl => { | opts } -> Effect Tracer
initTracer opts = runEffectFn1 initTracerImpl opts

-- Span reference for creating relationships
type SpanReference =
  { refType :: SpanReferenceType
  , spanContext :: SpanContext
  }

-- Start span options
type StartSpanOptionsImpl =
  ( childOf :: SpanContext
  , references :: Array SpanReference
  , tags :: { | TagsRow }
  , startTime :: Instant
  )

-- Constraint for tag records
type TagsRow = ()

foreign import startSpanImpl :: forall opts. EffectFn3 Tracer OperationName { | opts } Span

startSpan :: OperationName -> Tracer -> Effect Span
startSpan opName tracer = runEffectFn3 startSpanImpl tracer opName {}

startSpanWithOptions :: forall opts opts_. Union opts opts_ StartSpanOptionsImpl => OperationName -> { | opts } -> Tracer -> Effect Span
startSpanWithOptions opName opts tracer = runEffectFn3 startSpanImpl tracer opName opts

-- Helper for starting span with tags (most common case)
startSpanWithTags :: forall r. Homogeneous r TagValue => OperationName -> { | r } -> Tracer -> Effect Span
startSpanWithTags opName tags tracer = 
  runEffectFn3 startSpanImpl tracer opName { tags: unsafeCoerce (Object.fromHomogeneous tags) }

-- Start span as child
foreign import startSpanAsChildImpl :: EffectFn3 Tracer OperationName Span Span

startSpanAsChild :: OperationName -> Span -> Tracer -> Effect Span
startSpanAsChild opName parentSpan tracer = runEffectFn3 startSpanAsChildImpl tracer opName parentSpan

-- Get span context
foreign import getSpanContextImpl :: EffectFn1 Span SpanContext

getSpanContext :: Span -> Effect SpanContext
getSpanContext span = runEffectFn1 getSpanContextImpl span

-- Set tag
foreign import setTagImpl :: EffectFn3 Span String TagValue Unit

setTag :: String -> TagValue -> Span -> Effect Unit
setTag key value span = runEffectFn3 setTagImpl span key value

-- Set multiple tags
foreign import setTagsImpl :: EffectFn2 Span (Object TagValue) Unit

setTags :: forall r. Homogeneous r TagValue => { | r } -> Span -> Effect Unit
setTags tags span = runEffectFn2 setTagsImpl span (Object.fromHomogeneous tags)

-- Log fields
foreign import logImpl :: EffectFn2 Span (Object String) Unit

log :: forall r. Homogeneous r String => { | r } -> Span -> Effect Unit
log fields span = runEffectFn2 logImpl span (Object.fromHomogeneous fields)

-- Log with timestamp
foreign import logWithTimestampImpl :: EffectFn3 Span (Object String) Instant Unit

logWithTimestamp :: forall r. Homogeneous r String => { | r } -> Instant -> Span -> Effect Unit
logWithTimestamp fields timestamp span = runEffectFn3 logWithTimestampImpl span (Object.fromHomogeneous fields) timestamp

-- Set baggage item
foreign import setBaggageItemImpl :: EffectFn3 Span BaggageKey BaggageValue Unit

setBaggageItem :: BaggageKey -> BaggageValue -> Span -> Effect Unit
setBaggageItem key value span = runEffectFn3 setBaggageItemImpl span key value

-- Get baggage item
foreign import getBaggageItemImpl :: EffectFn2 Span BaggageKey (Nullable BaggageValue)

getBaggageItem :: BaggageKey -> Span -> Effect (Maybe BaggageValue)
getBaggageItem key span = do
  result <- runEffectFn2 getBaggageItemImpl span key
  pure $ toMaybe result

-- Set operation name
foreign import setOperationNameImpl :: EffectFn2 Span OperationName Unit

setOperationName :: OperationName -> Span -> Effect Unit
setOperationName opName span = runEffectFn2 setOperationNameImpl span opName

-- Finish span
foreign import finishSpanImpl :: EffectFn1 Span Unit

finishSpan :: Span -> Effect Unit
finishSpan span = runEffectFn1 finishSpanImpl span

-- Finish span with timestamp
foreign import finishSpanWithTimestampImpl :: EffectFn2 Span Instant Unit

finishSpanWithTimestamp :: Instant -> Span -> Effect Unit
finishSpanWithTimestamp timestamp span = runEffectFn2 finishSpanWithTimestampImpl span timestamp

-- Close tracer (flush and close)
foreign import closeTracerImpl :: EffectFn1 Tracer (Promise Unit)

closeTracer :: Tracer -> Aff Unit
closeTracer tracer = runEffectFn1 closeTracerImpl tracer # Promise.toAffE

-- Inject span context into carrier (for distributed tracing)
-- Returns Object String (e.g., HTTP headers)
foreign import injectImpl :: EffectFn3 Tracer SpanContext Format (Object String)

inject :: SpanContext -> Format -> Tracer -> Effect (Object String)
inject ctx format tracer = runEffectFn3 injectImpl tracer ctx format

-- Extract span context from carrier (takes homogeneous record or Object String)
foreign import extractImpl :: EffectFn3 Tracer Format (Object String) (Nullable SpanContext)

extract :: forall r. Homogeneous r String => Format -> { | r } -> Tracer -> Effect (Maybe SpanContext)
extract format carrier tracer = do
  result <- runEffectFn3 extractImpl tracer format (Object.fromHomogeneous carrier)
  pure $ toMaybe result

-- If you already have an Object String
extractFromObject :: Format -> Object String -> Tracer -> Effect (Maybe SpanContext)
extractFromObject format carrier tracer = do
  result <- runEffectFn3 extractImpl tracer format carrier
  pure $ toMaybe result

-- Helper functions for common span operations

-- Wrap an Effect action with a span
withSpan :: forall a. OperationName -> Tracer -> Effect a -> Effect a
withSpan opName tracer action = do
  span <- startSpan opName tracer
  result <- action
  finishSpan span
  pure result

-- Wrap an Aff action with a span
withSpanAff :: forall a. OperationName -> Tracer -> Aff a -> Aff a
withSpanAff opName tracer action = do
  span <- liftEffect $ startSpan opName tracer
  result <- action
  liftEffect $ finishSpan span
  pure result

-- Standard tag helpers
setErrorTag :: Boolean -> Span -> Effect Unit
setErrorTag isError span = setTag "error" (TagBoolean isError) span

newtype HTTPMethod = HTTPMethod String
derive instance Newtype HTTPMethod _
derive newtype instance Eq HTTPMethod
derive newtype instance Show HTTPMethod

setHTTPMethodTag :: HTTPMethod -> Span -> Effect Unit
setHTTPMethodTag (HTTPMethod method) span = setTag "http.method" (TagString method) span

newtype HTTPURL = HTTPURL String
derive instance Newtype HTTPURL _
derive newtype instance Eq HTTPURL
derive newtype instance Show HTTPURL

setHTTPURLTag :: HTTPURL -> Span -> Effect Unit
setHTTPURLTag (HTTPURL url) span = setTag "http.url" (TagString url) span

newtype HTTPStatusCode = HTTPStatusCode Int
derive instance Newtype HTTPStatusCode _
derive newtype instance Eq HTTPStatusCode
derive newtype instance Ord HTTPStatusCode
derive newtype instance Show HTTPStatusCode

setHTTPStatusCodeTag :: HTTPStatusCode -> Span -> Effect Unit
setHTTPStatusCodeTag (HTTPStatusCode code) span = setTag "http.status_code" (TagNumber $ toNumber code) span

newtype Component = Component String
derive instance Newtype Component _
derive newtype instance Eq Component
derive newtype instance Show Component

setComponentTag :: Component -> Span -> Effect Unit
setComponentTag (Component component) span = setTag "component" (TagString component) span

newtype SpanKind = SpanKind String
derive instance Newtype SpanKind _
derive newtype instance Eq SpanKind
derive newtype instance Show SpanKind

setSpanKindTag :: SpanKind -> Span -> Effect Unit
setSpanKindTag (SpanKind kind) span = setTag "span.kind" (TagString kind) span
