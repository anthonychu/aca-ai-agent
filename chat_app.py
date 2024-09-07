import os
from datetime import datetime, timedelta, timezone

import chainlit as cl
import dotenv
import langchain.agents
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from langchain import hub
from langchain.agents import AgentExecutor
from langchain.tools.retriever import create_retriever_tool
from langchain_azure_dynamic_sessions import SessionsPythonREPLTool
from langchain_experimental.tools import PythonREPLTool
from langchain_openai import AzureChatOpenAI
from common import vector_store
from prompt import prompt

dotenv.load_dotenv()


@cl.on_chat_start
async def on_chat_start():

    llm = AzureChatOpenAI(
        azure_deployment="gpt-35-turbo",
        openai_api_version="2023-09-15-preview",
        streaming=True,
        temperature=0,
        azure_ad_token_provider=get_bearer_token_provider(DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"),
        azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    )

    retriever = vector_store.as_retriever()

    retriever_tool = create_retriever_tool(
        retriever,
        "search_documents",
        "Searches and returns excerpts from documents that contain useful information.",
    )

    code_interpreter_tool = SessionsPythonREPLTool(
        pool_management_endpoint=os.environ["POOL_MANAGEMENT_ENDPOINT"],
    )
    code_interpreter_tool.description += " To see the result, you MUST use the `print` function."

    tools = [
        retriever_tool,
        code_interpreter_tool,
    ]

    react_agent = langchain.agents.create_react_agent(
        llm=llm,
        tools=tools,
        prompt=prompt,
    )

    react_agent_executor = AgentExecutor(
        agent=react_agent,
        tools=tools,
        verbose=True,
        handle_parsing_errors=True,
        return_intermediate_steps=True,
        max_iterations=10,
    )

    cl.user_session.set("agent", react_agent_executor)
    cl.user_session.set("repl", code_interpreter_tool)

@cl.on_message
async def on_message(message: cl.Message):
    agent = cl.user_session.get("agent")

    if message.elements:
        repl = cl.user_session.get("repl")
        is_sessions = isinstance(repl, SessionsPythonREPLTool)
        if is_sessions:
            repl.upload_file(local_file_path=message.elements[0].path, remote_file_path=message.elements[0].name)
            cl.user_session.set("latest_file", f"/mnt/data/{message.elements[0].name}")
        else:
            cl.user_session.set("latest_file", message.elements[0].path)

    latest_file = cl.user_session.get("latest_file")
    if latest_file:
        additional_info = (
            f"If you need to analyze or query data, there's a file uploaded to `{latest_file}`. "
            "Execute Python code to read the file and extract the data you need. "
            "Pandas is available. "
            "Always start by checking the first few rows to see what the data looks like, "
            "and then write additional queries to complete the analysis."
        )
    else:
        additional_info = "None"

    message_content = message.content

    res = await agent.ainvoke(
        input={
            "input": message_content,
            "chat_history": [],
            "additional_info": additional_info,
        },
    )

    async with cl.Step(name="AgentExecutor") as step:
        step.output = '\n'.join([a[0].log for a in res['intermediate_steps']])

    await cl.Message(content=res['output']).send()
