from pinecone import Pinecone, ServerlessSpec
from dotenv import load_dotenv
import os
from openai import OpenAI

#load dotenv for environement variables
load_dotenv()

#setup openai API
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
pc = Pinecone(api_key=os.getenv("PINECONE_API_KEY"))

def getRelevantStyles(str, index_name):

    index = pc.Index(index_name)

    response = client.embeddings.create(input=str, model="text-embedding-3-large")
    embedding = response.data[0].embedding
    
    query_result = index.query(
    vector=embedding,
    top_k=3,)

    results = []

    for vector in query_result["matches"]:
        results.append((vector["id"], vector["score"]))

    return results