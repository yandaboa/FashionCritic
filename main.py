### This file creates and populates the pinecone vectorDB

from pinecone import Pinecone, ServerlessSpec
from dotenv import load_dotenv
import os
from openai import OpenAI

from queryPCIndex import getRelevantStyles

#load dotenv for environement variables
load_dotenv()

#setup openai and pinecone API
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
pc = Pinecone(api_key=os.getenv("PINECONE_API_KEY"))

index_name="fit-labels"

def create_index(index_name):
    pc.create_index(
        name=index_name,
        dimension=3072, # Replace with your model dimensions
        metric="cosine", # Replace with your model metric
        spec=ServerlessSpec(
            cloud="aws",
            region="us-east-1"
        ) 
    )

def populate_index(index_name, fashion_styles):
    fashion_data = []

    for i in range(len(fashion_styles)):
        response = client.embeddings.create(
            model="text-embedding-3-large",
            input=fashion_styles[i]
        )
        fashion_data.append({"id": f"text-{i}", "values":response.data[0].embedding, "metadata":{'text': fashion_styles[i]}})

    pcindex = pc.Index(index_name)

    print(pcindex.describe_index_stats())

    pcindex.upsert(vectors=fashion_data)

    print(pcindex.describe_index_stats())

def check_pc_index(index_name):
    index = pc.Index(index_name)
    print(index.describe_index_stats())


#fashion styles we want embeddings for
fashion_styles = [
    "Casual: Relaxed and comfortable clothing for everyday wear. Common pieces include jeans, T-shirts, sneakers, hoodies, and simple dresses.",
    "Professional: Tailored and polished outfits suitable for work or formal settings. Common pieces include blazers, dress shirts, trousers, pencil skirts, and loafers.",
    "Streetwear: Urban and trendy, influenced by hip-hop, skate culture, and youth fashion. Common pieces include oversized hoodies, graphic T-shirts, cargo pants, and sneakers.",
    "Evening Wear: Elegant and sophisticated attire for special occasions. Common pieces include gowns, suits, tuxedos, dress shoes, and accessories like ties or clutches.",
    "Athleisure: A blend of athletic and leisurewear, combining functionality with style. Common pieces include leggings, joggers, sports bras, sneakers, and zip-up jackets.",
    "Bohemian: Free-spirited and artistic, inspired by the hippie movement. Common pieces include flowing dresses, fringe details, earthy tones, and layered jewelry.",
    "Preppy: Polished and youthful, inspired by Ivy League fashion. Common pieces include polo shirts, chinos, pleated skirts, cardigans, and loafers.",
    "Minimalist: Simple, clean, and understated with neutral tones and streamlined designs. Common pieces include plain tops, tailored trousers, monochrome outfits, and minimal accessories.",
    "Romantic: Feminine and delicate, with an emphasis on soft fabrics and pretty details. Common pieces include lace blouses, floral dresses, ruffles, and pastel colors.",
    "Edgy: Bold and rebellious, often inspired by punk or rock aesthetics. Common pieces include leather jackets, ripped jeans, combat boots, and dark tones."
]

# populate_index(index_name=index_name, fashion_styles=fashion_styles)

check_pc_index(index_name=index_name)

test_string = "I'm going out to a nice restuarant tonight for a date, what should I wear? I'm a guy."

closest_results = getRelevantStyles(test_string, index_name=index_name)

for result in closest_results:
    index = int(result[0].split("-")[1])
    if (result[1] > 0.3):
        print("Match: " + fashion_styles[index].split(":")[0])
        print(result[1])
    else:
        print("not close enough: " + fashion_styles[index].split(":")[0])
        print(result[1])