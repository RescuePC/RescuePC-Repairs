export const metadata = {
  title: 'RescuePC Licensing API',
  description: 'License validation API for RescuePC',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}

