'use client'
import { useState } from 'react'

const Home = () => {
  const [response, setResponse] = useState<string>('')

  const handleBackend = async (e: React.FormEvent) => {
    e.preventDefault()
    console.log('Button clicked: ', process.env.NEXT_PUBLIC_API_URL)

    try {
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api`)
      const data = await res.json() 
      setResponse(data.message)
      console.log("data: ", data)
    } catch (error) {
      console.error(error)
    }
  }
  const handleDatabase = async (e: React.FormEvent) => {
    e.preventDefault()
    console.log('Button clicked: ', process.env.NEXT_PUBLIC_API_URL)

    try {
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/data`)
      const data = await res.json() 
      setResponse(data.Date)
      console.log("data: ", data)
    } catch (error) {
      console.error(error)
    }
  }

  return (
    <>
    <div className="h-screen w-full bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500 flex flex-col items-center justify-center text-white">
      <h1 className="text-5xl font-extrabold text-center mb-6">Welcome to the Next.js App</h1>
      <div className="flex flex-col gap-6 items-center justify-center p-6 bg-white rounded-xl shadow-lg w-96">
        <button
          onClick={handleBackend}
          className="w-full py-3 px-6 rounded-md border-2 border-blue-600 bg-sky-600 text-white font-semibold transition-all hover:bg-sky-700 focus:outline-none focus:ring-2 focus:ring-blue-400 focus:ring-opacity-50"
        >
          Send request to backend
        </button>
        <button
          onClick={handleDatabase}
          className="w-full py-3 px-6 rounded-md border-2 border-green-600 bg-teal-600 text-white font-semibold transition-all hover:bg-teal-700 focus:outline-none focus:ring-2 focus:ring-teal-400 focus:ring-opacity-50"
        >
          Send request to database
        </button>
        <p className="text-lg text-center text-gray-800 mt-4">{response}</p>
      </div>
    </div>
  </>
  )
}

export default Home
