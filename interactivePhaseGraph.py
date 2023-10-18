import dash
from dash import dcc, html
from dash import dash_table
from dash.dependencies import Input, Output, State
import plotly.express as px
from plotly.subplots import make_subplots
import plotly.graph_objects as go
import argparse
import time
import numpy as np
from matplotlib import cm

colors = {
    'dark': True,
    'background': 'rgb(30,30,30)',
    'text': 'rgb(220,220,220)',
    'col1': 'rgb(63,124,150)',
    'col2': 'rgb(105,160,140)',
    'col3': '#21918c',
    'col4': '#3b528b'
}


# Initialize Dash app
app = dash.Dash(__name__)

# initialize the layout 
app.layout = html.Div(style={'backgroundColor': colors['background']},children=[
    html.H1(children='Interactive Three-Pulse Phase Graph', style={'textAlign':'center', 'color':colors['text']}),
    dcc.Graph(id='phasegraph'),
    dcc.Markdown('Flip Angle 1', style={'color':colors['text']}),
    dcc.Slider(0,180,step=4,updatemode='drag',
               marks={0: '0°',
                      45: '45°',
                      90: {'label':'90°', 'style':{'color': colors['text'], 'size':'28px'}},
                      135: '135°',
                      180: '180°'},
               value=90.0, id='fa1',
               tooltip={"placement": "bottom", "always_visible": True}),
    dcc.Markdown('Flip Angle 2', style={'color':colors['text']}),
    dcc.Slider(0,180,step=4,updatemode='drag',
               marks={0: '0°',
                      45: '45°',
                      90: '90°',
                      135: '135°',
                      180: '180°'},
               value=110.0, id='fa2',
               tooltip={"placement": "bottom", "always_visible": True}),
    dcc.Markdown('Flip Angle 3', style={'color':colors['text']}),
    dcc.Slider(0,180,step=4,updatemode='drag',
               marks={0: '0°',
                      45: '45°',
                      90: '90°',
                      135: '135°',
                      180: '180°'},
               value=110.0, id='fa3',
               tooltip={"placement": "bottom", "always_visible": True}),
    dcc.Markdown('$$𝜏_2/c_1$$', mathjax=True, style={'color':colors['text']}),
    dcc.Slider(0.5, 2.5, step=0.125/2, updatemode='drag',
               marks={0.5: '0.5',
                      1.5: '1.5', 
                      3.5: '3.5'},
               value=1.5, id='time',
               tooltip={"placement": "bottom", "always_visible": True})
])

# update the phase graph 
@app.callback(
    Output('phasegraph', 'figure'),
    Input('fa1', 'value'),
    Input('fa2','value'),
    Input('fa3','value'),
    Input('time','value')
)
def updatePhaseGraph(fa1, fa2, fa3, tfrac):

    a1 = fa1 * np.pi / 180
    a2 = fa2 * np.pi / 180
    a3 = fa3 * np.pi / 180 
    tau12 = 1.0 
    tau23 = tfrac * tau12 
    #tau_post = tau12 + 1.5*tau23
    tau_post = 7.0 - tau12 - tau23


    # keep track of all start/end phases, times, and magnetization
    nseg = 20 
    p1 = np.zeros((nseg,),dtype=np.float32) # phase at start of segment
    p2 = np.zeros((nseg,),dtype=np.float32) # phase at end of segment
    t1 = np.zeros((nseg,),dtype=np.float32) # time at beginning of segment
    t2 = np.zeros((nseg,),dtype=np.float32) # time at end of segment
    m = np.zeros((nseg,),dtype=np.complex64)
    echoAtTime = [0] * nseg
    isMz = [False] * nseg

    #------------#
    # RF Pulse 1 #
    #------------#

    # segment 0: FID from first RF pulse 
    p1[0] = 0.0
    p2[0] = tau12 
    t1[0] = 0.0 
    t2[0] = tau12 
    m[0] = np.sin(a1)

    # segment 1: fresh longitudinal magnetization 
    p1[1] = 0.0 
    p2[1] = 0.0
    t1[1] = 0.0
    t2[1] = tau12 
    m[1] = np.cos(a1)
    isMz[1] = True

    # segment 2: FID from segment 0 continues to dephase 
    p1[2] = p2[0]
    p2[2] = p1[2] + tau23 
    t1[2] = tau12 
    t2[2] = tau12 + tau23 
    m[2] = np.sin(a1) * np.cos(a2/2) * np.cos(a2/2)

    # segment 3: flip back of magnetization from segment 0 to z axis 
    p1[3] = p2[0]
    p2[3] = p2[0]
    t1[3] = tau12 
    t2[3] = tau12 + tau23 
    m[3] = np.sin(a1) * np.sin(a2) 
    isMz[3] = True

    # segment 4: new FID from second RF pulse acting on fresh Mz 
    p1[4] = 0.0
    p2[4] = tau23 
    t1[4] = tau12 
    t2[4] = tau12 + tau23 
    m[4] = np.cos(a1) * np.sin(a2) 

    # segment 5: fresh longitudinal magnetization remaining after second RF
    p1[5] = 0.0
    p2[5] = 0.0
    t1[5] = tau12 
    t2[5] = tau12 + tau23 
    m[5] = np.cos(a1) * np.cos(a2) 
    isMz[5] = True 

    # segment 6: refocusing of magnetization from segment 0
    p1[6] = -p2[0]
    p2[6] = p1[6] + tau23 
    t1[6] = tau12 
    t2[6] = tau12 + tau23 
    m[6] = np.sin(a1) * np.sin(a2/2) * np.sin(a2/2)
    echoAtTime[6] = 2*tau12 

    # segment 7: segment 2 continues to dephase after RF 3
    p1[7] = p2[2]
    p2[7] = p1[7] + tau_post 
    t1[7] = tau12 + tau23 
    t2[7] = tau12 + tau23 + tau_post 
    m[7] = np.sin(a1) * np.cos(a2/2) * np.cos(a2/2) * np.cos(a3/2) * np.cos(a3/2)

    # segment 8: segment 4 continues to dephase after RF 3
    p1[8] = p2[4]
    p2[8] = p1[8] + tau_post 
    t1[8] = tau12 + tau23 
    t2[8] = tau12 + tau23 + tau_post
    m[8] = np.cos(a1) * np.sin(a2) * np.cos(a3/2) * np.cos(a3/2)

    # segment 9: segment 6 continues to dephase after RF 3
    p1[9] = p2[6]
    p2[9] = p1[9] + tau_post 
    t1[9] = tau12 + tau23 
    t2[9] = tau12 + tau23 + tau_post
    m[9] = np.sin(a1) * np.sin(a2/2) * np.sin(a2/2) * np.cos(a3/2) * np.cos(a3/2) 

    # segment 10: FID of remaining fresh longitudinal magnetization from RF 3
    p1[10] = 0.0
    p2[10] = tau_post 
    t1[10] = tau12 + tau23 
    t2[10] = tau12 + tau23 + tau_post
    m[10] = np.cos(a1) * np.cos(a2) * np.sin(a3)

    # segment 11: refocusing of segment 6 via RF 3
    p1[11] = -p2[6]
    p2[11] = p1[11] + tau_post 
    t1[11] = tau12 + tau23 
    t2[11] = tau12 + tau23 + tau_post
    m[11] = np.sin(a1) * np.sin(a2/2) * np.sin(a2/2) * np.sin(a3/2) * np.sin(a3/2)
    echoAtTime[11] = 2*tau12 + 2*(tau23-tau12)

    # segment 12: RF 3 flipping portion of segment 2 back along longitudinal axis
    p1[12] = p2[2]
    p2[12] = p1[12]
    t1[12] = tau12 + tau23 
    t2[12] = tau12 + tau23 + tau_post
    m[12] = np.sin(a1) * np.cos(a2/2) * np.cos(a2/2) * np.sin(a3) 
    isMz[12] = True

    # segment 13: stimulated echo (tipping into transverse plane and refocusing the longitudinal magnetization in segment 3)
    p1[13] = -p2[3]
    p2[13] = p1[13] + tau_post 
    t1[13] = tau12 + tau23 
    t2[13] = tau12 + tau23 + tau_post
    m[13] = np.sin(a1) * np.sin(a2) * np.sin(a3) 
    echoAtTime[13] = tau23 + 2*tau12

    # segment 14: refocusing of segment 4 via RF 3 
    p1[14] = -p2[4]
    p2[14] = p1[14] + tau_post 
    t1[14] = tau12 + tau23 
    t2[14] = tau12 + tau23 + tau_post
    m[14] = np.cos(a1) * np.sin(a2) * np.sin(a3/2) * np.sin(a3/2) 
    echoAtTime[14] = tau12 + 2*tau23
    
    # segment 15: flipping part of segment 4 back onto longitudinal axis via RF 3
    p1[15] = p2[4] 
    p2[15] = p1[15]
    t1[15] = tau12 + tau23 
    t2[15] = tau12 + tau23 + tau_post
    m[15] = np.cos(a1) * np.sin(a2) * np.sin(a3) 
    isMz[15] = True 

    # segment 16: refocusing of segment 2 via RF 3 
    p1[16] = -p2[2]
    p2[16] = p1[16] + tau_post 
    t1[16] = tau12 + tau23 
    t2[16] = tau12 + tau23 + tau_post
    m[16] = np.sin(a1) * np.cos(a2/2) * np.cos(a2/2) * np.sin(a3/2) * np.sin(a3/2) 
    echoAtTime[16] = 2*(tau12 + tau23)

    # segment 17: flipping back magnetization from segment 6 along longitudinal axis via RF 3
    p1[17] = p2[6]
    p2[17] = p1[17]
    t1[17] = tau12 + tau23 
    t2[17] = tau12 + tau23 + tau_post
    m[17] = np.sin(a1) * np.sin(a2/2) * np.sin(a2/2) * np.sin(a3) 
    isMz[17] = True 

    # segment 18: remaining untouched longitudinal magnetization 
    p1[18] = 0.0
    p2[18] = 0.0
    t1[18] = tau12 + tau23 
    t2[18] = tau12 + tau23 + tau_post
    m[18] = np.cos(a1) * np.cos(a2) * np.cos(a3)
    isMz[18] = True 

    # segment 19: Mz in segment 3 stays along longitudinal axis 
    p1[19] = p2[3]
    p2[19] = p1[19]
    t1[19] = tau12 + tau23 
    t2[19] = tau12 + tau23 + tau_post
    m[19] = np.sin(a1) * np.sin(a2) * np.cos(a3) 
    isMz[19] = True 

    inds = np.argsort(np.abs(m))
    isMz = np.array(isMz, dtype=np.int32)
    echoAtTime = np.array(echoAtTime, dtype=np.float32)
    p1 = p1[inds]
    p2 = p2[inds]
    t1 = t1[inds]
    t2 = t2[inds]
    m = m[inds]
    isMz = isMz[inds]
    echoAtTime = echoAtTime[inds]

    # viridis = cm.get_cmap('viridis', 256)
    cmap = cm.get_cmap('viridis', 256)

    fig = make_subplots(rows=1, cols=1)
    for n in range(p1.size):
        x = np.array([t1[n], t2[n]])
        y = np.array([p1[n], p2[n]])
        c = cmap(np.abs(m[n]))
        c = (int(c[0]*255.0), int(c[1]*255), int(c[2]*255))
        color = '#%02x%02x%02x' % c
        fig.add_trace(go.Scatter(x=x, y=y, showlegend=False), row=1, col=1)
        fig['data'][-1]['line']['color'] = color

    for n in range(p1.size):
        if echoAtTime[n] > 0: 
            x = np.array([echoAtTime[n]])
            y = np.array([0.0])
            fig.add_trace(go.Scatter(x=x, y=y, showlegend=False), row=1, col=1)
            fig['data'][-1]['line']['color'] = 'rgb(196,50,65)'
    fig.update_traces(marker_size=10)
    fig.update_layout(plot_bgcolor=colors['background'],paper_bgcolor=colors['background'],font=dict(family='times new roman',size=24))
    fig.update_xaxes(color=colors['text'], showgrid=False)
    fig.update_yaxes(color=colors['text'], showgrid=False)
    fig.update_coloraxes(colorbar_tickcolor=colors['text'])

    fig.update_layout(
    xaxis = dict(
        tickmode = 'array',
        tickvals = [tau12, tau12+tau23],
        ticktext = ['𝜏1', '𝜏1 + 𝜏2']
    ))




    return fig


# Run app
if __name__ == '__main__':
    app.run_server(debug=False)