from dotenv import load_dotenv
import os
from openai import OpenAI

load_dotenv()

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

response = client.chat.completions.create(
  model="gpt-4o-mini",
  messages=[
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Give specific advice for someone who wants to change their style from the first image to the second. Briefly describe the differences in styles, and then give actionable advice on what clothing pieces to buy or thrift for. Specifically, give advice for only: top, bottoms, shoes, accessories.\n\nExample of output format (don't use anything other than plain text and colons):\nAdvice: Yo, you're dressing quite casually. Usually, formal ware conveys a more professional demeanor, and that's not what your shoes and shirt communicate.\nTop: Grab a button shirt t-shirt. Look for a high-quality cotton shirt with a smooth finish, like poplin or twill. Ensure it fits well (tailored or slim-fit for a modern look).\nWhere: Zara, Uniqlo, Men's Wearhouse.\nPants: The darker jeans you have are quite nice. Perhaps go with dress pants if you want more formal. Choose trousers made of high-quality wool or a wool blend for a polished, formal look. Flat-front trousers are sleek and modern, ideal for slimmer builds. Pleated trousers offer extra comfort and room, suitable for more traditional formal outfits.\nWhere: Men's Wearhouse, Levi's\n...",
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "https://www.instyle.com/thmb/_PFAdCOUxiQ63d4t7kzQHlZZ8TA=/1500x0/filters:no_upscale():max_bytes(150000):strip_icc()/GettyImages-1375733223-2d201785e168434e9bc3d8da99c1f067.jpg",
          },
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "https://media.glamour.com/photos/5e18e5cd641e100008c62a6e/master/w_2560%2Cc_limit/big-collars.jpg",
          },
        },
      ],
    }
  ],
  max_tokens=300,
)

print(response.choices[0].message.content)