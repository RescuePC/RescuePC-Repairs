type JsonPrimitive = string | number | boolean | null;
type JsonValue = JsonPrimitive | JsonValue[] | { [key: string]: JsonValue };

type JsonLdProps = {
  data: JsonValue;
  id?: string;
};

function safeJsonStringify(data: JsonValue) {
  return JSON.stringify(data).replace(/</g, "\\u003c");
}

export default function JsonLd({ data, id }: JsonLdProps) {
  return (
    <script
      id={id}
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: safeJsonStringify(data) }}
    />
  );
}
